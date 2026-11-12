import AVFoundation
import Foundation
import os
import Speech
#if canImport(Retold)
@testable import Retold
#endif

// The transcription harness core (listening hardening, 2026-11-12). It drives the app's own capture
// code with recorded speech and records raw timings; harness/score.py turns them into WER, missing
// stretches and latency. Two hosts compile this file:
// - the RetoldListenHarness test bundle on the iOS simulator (`@testable import Retold`);
// - a macOS command-line build that compiles the same app sources directly (harness/macos/).
// Only platform-neutral app code is used: SpeechModules, LiveTranscription, TapSink,
// CaptureAudioFile, SpeechFileTranscriber, SpeechRouteProbe, AssetPrefetch.

struct HarnessEvent: Codable, Sendable {
    let kind: String        // "volatile" | "final"
    let text: String
    let start: Double       // audio time, seconds
    let end: Double
    let wall: Double        // seconds since the first buffer was pushed
}

struct HarnessLiveRun: Codable, Sendable {
    var inputFormat = ""
    var path = ""           // "converter" | "passthrough"
    var pushes: [[Double]] = []   // [audio seconds pushed so far, wall seconds at push]
    var events: [HarnessEvent] = []
    var stopWall = 0.0
    var doneWall = 0.0
    var completed = false
    var writeError = false
    var convertDrops = 0
    var buffers = 0
    var error: String?
}

struct HarnessFilePass: Codable, Sendable {
    var segments: [HarnessEvent] = []   // wall = 0
    var elapsed = 0.0
    var error: String?
}

struct HarnessFixtureResult: Codable, Sendable {
    let name: String
    let reference: String
    let duration: Double
    var live: HarnessLiveRun?
    var fileFromRecording: HarnessFilePass?
    var fileFromSource: HarnessFilePass?
}

struct HarnessProbe: Codable, Sendable {
    var host = ""
    var os = ""
    var locale = ""
    var speechTranscriberAvailable = false
    var routeBefore = ""
    var routeAfter = ""
    var prefetchSeconds = 0.0
    var prefetchTimedOut = false
    var notes: [String] = []
}

struct HarnessReport: Codable, Sendable {
    var schema = "retold-listen-harness/v1"
    var variant = ""
    var probe = HarnessProbe()
    var fixtures: [HarnessFixtureResult] = []
}

/// A fixture on disk: `<name>.wav` (48 kHz Float32 mono, like the iPhone mic) and `<name>.txt`
/// (the reference words).
struct HarnessFixture: Sendable {
    let name: String
    let audioURL: URL
    let reference: String

    static func load(from directory: URL) -> [HarnessFixture] {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".wav") }
            .sorted()
        return names.compactMap { file in
            let name = String(file.dropLast(4))
            let audio = directory.appendingPathComponent(file)
            let textURL = directory.appendingPathComponent(name + ".txt")
            guard let reference = try? String(contentsOf: textURL, encoding: .utf8) else { return nil }
            return HarnessFixture(name: name, audioURL: audio, reference: reference)
        }
    }
}

enum ListenHarness {
    /// The variant label printed in the report (which code the run measured).
    static let variant = "baseline"
    /// The tap's requested buffer size in LiveCaptureEngine.
    static let tapBufferFrames: AVAudioFrameCount = 4096

    private static func wallClock() -> @Sendable () -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        return { Double(DispatchTime.now().uptimeNanoseconds &- start) / 1e9 }
    }

    // MARK: - Probe

    /// Route before and after the app's own asset prefetch, bounded by `timeout`.
    static func probe(host: String, timeout: TimeInterval) async -> (HarnessProbe, TranscriptionRoute) {
        var probe = HarnessProbe()
        probe.host = host
        probe.os = ProcessInfo.processInfo.operatingSystemVersionString
        probe.locale = Locale.current.identifier
        probe.speechTranscriberAvailable = SpeechTranscriber.isAvailable
        let before = await SpeechRouteProbe().currentRoute()
        probe.routeBefore = before.journalTag
        log("probe: available=\(probe.speechTranscriberAvailable) locale=\(probe.locale) route=\(before.journalTag)")

        if case .audioOnly = before {
            let done = OSAllocatedUnfairLock(initialState: false)
            let clock = wallClock()
            Task.detached {
                await AssetPrefetch().run()
                done.withLock { $0 = true }
            }
            while !done.withLock({ $0 }) && clock() < timeout {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            probe.prefetchSeconds = clock()
            probe.prefetchTimedOut = !done.withLock { $0 }
            log("probe: prefetch \(probe.prefetchTimedOut ? "timed out" : "finished") after \(Int(probe.prefetchSeconds))s")
        }
        let after = await SpeechRouteProbe().currentRoute()
        probe.routeAfter = after.journalTag
        log("probe: route after prefetch=\(after.journalTag)")
        return (probe, after)
    }

    // MARK: - Runs

    /// Runs every fixture through the live path and the file pass. Never throws: failures are
    /// recorded per fixture so one bad fixture cannot hide the rest.
    static func runAll(fixtures: [HarnessFixture], host: String, workDirectory: URL,
                       prefetchTimeout: TimeInterval = 300) async -> HarnessReport {
        var report = HarnessReport()
        report.variant = variant
        let (probe, route) = await probe(host: host, timeout: prefetchTimeout)
        report.probe = probe
        if case .audioOnly = route {
            report.probe.notes.append("no speech route on this host; nothing transcribed")
            return report
        }
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        for fixture in fixtures {
            log("fixture \(fixture.name): live run")
            let duration = (try? AVAudioFile(forReading: fixture.audioURL)).map {
                Double($0.length) / $0.processingFormat.sampleRate
            } ?? 0
            var result = HarnessFixtureResult(name: fixture.name, reference: fixture.reference, duration: duration)
            let recording = workDirectory.appendingPathComponent(fixture.name + ".m4a")
            result.live = await runLive(fixture: fixture, route: route, recordingURL: recording)
            log("fixture \(fixture.name): file pass over the recording")
            result.fileFromRecording = await runFilePass(audioURL: recording, route: route)
            log("fixture \(fixture.name): file pass over the source")
            result.fileFromSource = await runFilePass(audioURL: fixture.audioURL, route: route)
            report.fixtures.append(result)
        }
        return report
    }

    /// The live path as LiveCaptureEngine runs it: the same file settings, LiveTranscription and
    /// TapSink, fed tap-sized buffers at real-time pace.
    static func runLive(fixture: HarnessFixture, route: TranscriptionRoute,
                        recordingURL: URL) async -> HarnessLiveRun {
        var run = HarnessLiveRun()
        do {
            let source = try AVAudioFile(forReading: fixture.audioURL)
            let inputFormat = source.processingFormat
            run.inputFormat = "\(inputFormat)"
            try? FileManager.default.removeItem(at: recordingURL)
            let file = try AVAudioFile(forWriting: recordingURL,
                                       settings: CaptureAudioFile.settings(for: inputFormat),
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let module = SpeechModules.module(for: route, live: true) else {
                run.error = "no module for \(route.journalTag)"
                return run
            }
            let transcription = try await LiveTranscription.start(module: module, inputFormat: inputFormat)
            run.path = transcription.converter == nil ? "passthrough" : "converter"
            let sink = TapSink(file: file, converter: transcription.converter, builder: transcription.input)

            let clock = wallClock()
            let events = OSAllocatedUnfairLock<[HarnessEvent]>(initialState: [])
            transcription.startResults { result in
                let event = HarnessEvent(kind: result.isFinal ? "final" : "volatile", text: result.text,
                                         start: result.start, end: result.end, wall: clock())
                events.withLock { $0.append(event) }
            }

            let sampleRate = inputFormat.sampleRate
            var framesPushed: AVAudioFramePosition = 0
            while source.framePosition < source.length {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: tapBufferFrames) else {
                    break
                }
                try source.read(into: buffer, frameCount: tapBufferFrames)
                if buffer.frameLength == 0 { break }
                sink.consume(buffer)
                run.buffers += 1
                framesPushed += AVAudioFramePosition(buffer.frameLength)
                let audioPushed = Double(framesPushed) / sampleRate
                run.pushes.append([audioPushed, clock()])
                let wait = audioPushed - clock()
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1e9))
                }
            }

            run.stopWall = clock()
            run.completed = await transcription.finish()
            run.doneWall = clock()
            file.close()
            run.writeError = sink.writeError
            run.convertDrops = sink.convertDrops
            run.events = events.withLock { $0 }
        } catch {
            run.error = "\(error)"
        }
        return run
    }

    /// The file pass the coordinator runs (SpeechFileTranscriber), timed.
    static func runFilePass(audioURL: URL, route: TranscriptionRoute) async -> HarnessFilePass {
        var pass = HarnessFilePass()
        let clock = wallClock()
        do {
            for try await segment in SpeechFileTranscriber().transcribe(audioURL: audioURL, route: route) {
                pass.segments.append(HarnessEvent(kind: "final", text: segment.text,
                                                  start: segment.start, end: segment.end, wall: 0))
            }
        } catch {
            pass.error = "\(error)"
        }
        pass.elapsed = clock()
        return pass
    }

    static func encode(_ report: HarnessReport) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(report)) ?? Data("{}".utf8)
    }

    static func log(_ message: String) {
        print("LISTEN_HARNESS: \(message)")
    }
}
