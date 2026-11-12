import AVFoundation
import Foundation
import os
import Speech

// The transcription harness core (listening hardening, 2026-11-12). It drives the app's own capture
// code with recorded speech and records raw timings; harness/score.py turns them into WER, missing
// stretches and latency. Three hosts run it:
// - the Listening self-test inside the app (TestFlight and Debug only, ListenSelfTestView), the only
//   host with a working recognizer (docs/research/LISTEN-HARNESS-PROBE-2026-11-12.md);
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
    var contextualStrings: [String] = []
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

/// One tuning's results over every fixture.
struct HarnessVariant: Codable, Sendable {
    let tuning: ListenTuning
    var fixtures: [HarnessFixtureResult] = []
}

struct HarnessReport: Codable, Sendable {
    var schema = "retold-listen-harness/v2"
    var probe = HarnessProbe()
    var startedAt = ""
    var finishedAt = ""
    /// Per fixture, the order the tunings ran in (rotated, so a warm model is not credited to a tuning).
    var order: [String: [String]] = [:]
    var variants: [HarnessVariant] = []
}

/// A fixture on disk: `<name>.wav` or `<name>.m4a` (48 kHz mono, like the iPhone mic), `<name>.txt`
/// (the reference words), and optionally `<name>.names` (contextual strings, one per line: the
/// names and places a user would already have filed).
struct HarnessFixture: Sendable {
    let name: String
    let audioURL: URL
    let reference: String
    let contextualStrings: [String]

    static func load(from directory: URL) -> [HarnessFixture] {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
        return files.compactMap { file in
            guard file.hasSuffix(".wav") || file.hasSuffix(".m4a") else { return nil }
            let name = String(file.dropLast(4))
            let audio = directory.appendingPathComponent(file)
            let textURL = directory.appendingPathComponent(name + ".txt")
            guard let reference = try? String(contentsOf: textURL, encoding: .utf8) else { return nil }
            let namesURL = directory.appendingPathComponent(name + ".names")
            let names = ((try? String(contentsOf: namesURL, encoding: .utf8)) ?? "")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return HarnessFixture(name: name, audioURL: audio, reference: reference, contextualStrings: names)
        }
    }
}

enum ListenHarness {
    /// The tunings the self-test compares, `.current` first (the baseline).
    static let tunings: [ListenTuning] = [.current, .steady, .fast]
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
        if case .audioOnly = after {
            // A timed-out prefetch means the install hangs here; do not try it a second time.
            probe.notes += await assetDiagnostics(tryInstall: !probe.prefetchTimedOut)
        }
        return (probe, after)
    }

    /// Why no route: locales, asset status and the install request's error, which AssetPrefetch
    /// swallows by design.
    static func assetDiagnostics(tryInstall: Bool) async -> [String] {
        var notes: [String] = []
        let locale = Locale(identifier: "en-US")
        let speechLocales = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
        let speechInstalled = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
        let dictationLocales = await DictationTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
        notes.append("SpeechTranscriber supported locales: \(speechLocales.count) (en-US: \(speechLocales.contains("en-US"))), installed: \(speechInstalled)")
        notes.append("DictationTranscriber supported locales: \(dictationLocales.count) (en-US: \(dictationLocales.contains("en-US")))")
        let modules: [(String, any SpeechModule)] = [
            ("speech", SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [],
                                         attributeOptions: [.audioTimeRange])),
            ("dictation", DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [],
                                               reportingOptions: [], attributeOptions: [.audioTimeRange])),
        ]
        for (name, module) in modules {
            let status = await AssetInventory.status(forModules: [module])
            var line = "\(name) en-US asset status: \(status)"
            do {
                if !tryInstall {
                    line += "; install not retried"
                } else if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    try await request.downloadAndInstall()
                    line += "; install request finished, status now \(await AssetInventory.status(forModules: [module]))"
                } else {
                    line += "; no install request needed"
                }
            } catch {
                line += "; install error: \(error)"
            }
            notes.append(line)
        }
        notes.forEach { log("probe: \($0)") }
        return notes
    }

    // MARK: - Runs

    /// Runs every fixture through the live path and the file pass, once per tuning, rotating the
    /// tuning order per fixture. Never throws: failures are recorded per fixture so one bad fixture
    /// cannot hide the rest. `progress` gets one line per step (any thread).
    static func runAll(fixtures: [HarnessFixture], host: String, workDirectory: URL,
                       tunings: [ListenTuning] = ListenHarness.tunings,
                       prefetchTimeout: TimeInterval = 300,
                       progress: @escaping @Sendable (String) -> Void = { _ in }) async -> HarnessReport {
        var report = HarnessReport()
        report.startedAt = ISO8601DateFormatter().string(from: Date())
        report.variants = tunings.map { HarnessVariant(tuning: $0) }
        let (probe, route) = await probe(host: host, timeout: prefetchTimeout)
        report.probe = probe
        progress("route: \(route.journalTag)")
        if case .audioOnly = route {
            report.probe.notes.append("no speech route on this host; nothing transcribed")
            report.finishedAt = ISO8601DateFormatter().string(from: Date())
            return report
        }
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        for (fixtureIndex, fixture) in fixtures.enumerated() {
            let duration = (try? AVAudioFile(forReading: fixture.audioURL)).map {
                Double($0.length) / $0.processingFormat.sampleRate
            } ?? 0
            let rotation = fixtureIndex % max(1, tunings.count)
            let order = Array(tunings.indices.dropFirst(rotation)) + Array(tunings.indices.prefix(rotation))
            report.order[fixture.name] = order.map { tunings[$0].name }
            for index in order {
                let tuning = tunings[index]
                let strings = tuning.useContext ? fixture.contextualStrings : []
                var result = HarnessFixtureResult(name: fixture.name, reference: fixture.reference,
                                                  duration: duration, contextualStrings: strings)
                let recording = workDirectory.appendingPathComponent("\(fixture.name)-\(tuning.name).m4a")
                progress("\(fixture.name) [\(tuning.name)]: live, \(Int(duration))s")
                result.live = await runLive(fixture: fixture, route: route, tuning: tuning,
                                            contextualStrings: strings, recordingURL: recording)
                progress("\(fixture.name) [\(tuning.name)]: file pass")
                result.fileFromRecording = await runFilePass(audioURL: recording, route: route,
                                                             tuning: tuning, contextualStrings: strings)
                result.fileFromSource = await runFilePass(audioURL: fixture.audioURL, route: route,
                                                          tuning: tuning, contextualStrings: strings)
                try? FileManager.default.removeItem(at: recording)
                report.variants[index].fixtures.append(result)
            }
        }
        report.finishedAt = ISO8601DateFormatter().string(from: Date())
        progress("done")
        return report
    }

    /// The live path as LiveCaptureEngine runs it: the same file settings, LiveTranscription and
    /// TapSink, fed tap-sized buffers at real-time pace.
    static func runLive(fixture: HarnessFixture, route: TranscriptionRoute, tuning: ListenTuning,
                        contextualStrings: [String], recordingURL: URL) async -> HarnessLiveRun {
        var run = HarnessLiveRun()
        do {
            let source = try AVAudioFile(forReading: fixture.audioURL)
            let inputFormat = source.processingFormat
            run.inputFormat = "\(inputFormat)"
            try? FileManager.default.removeItem(at: recordingURL)
            let file = try AVAudioFile(forWriting: recordingURL,
                                       settings: CaptureAudioFile.settings(for: inputFormat),
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let module = SpeechModules.module(for: route, live: true, tuning: tuning) else {
                run.error = "no module for \(route.journalTag)"
                return run
            }
            let transcription = try await LiveTranscription.start(module: module, inputFormat: inputFormat,
                                                                  tuning: tuning,
                                                                  contextualStrings: contextualStrings)
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
            run.completed = await transcription.finish(flushing: sink)
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
    static func runFilePass(audioURL: URL, route: TranscriptionRoute, tuning: ListenTuning,
                            contextualStrings: [String]) async -> HarnessFilePass {
        var pass = HarnessFilePass()
        let clock = wallClock()
        do {
            let transcriber = SpeechFileTranscriber(tuning: tuning, contextualStrings: contextualStrings)
            for try await segment in transcriber.transcribe(audioURL: audioURL, route: route) {
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
