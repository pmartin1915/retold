import AVFoundation
import Foundation
import Speech

/// The real CaptureEngine: AVAudioEngine tap -> AVAudioFile + SpeechAnalyzer (spec 7).
/// @unchecked Sendable justification: all mutable state is touched only inside the protocol
/// methods, which the coordinator awaits one at a time on one serial task, and from the tap,
/// which touches only its TapSink (whose flag is a plain Bool written by the tap, read by stop).
final class LiveCaptureEngine: CaptureEngine, @unchecked Sendable {
    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()

    private let eventsStream: AsyncStream<CaptureEngineEvent>
    private let eventsContinuation: AsyncStream<CaptureEngineEvent>.Continuation

    /// State of the one in-flight capture; nil between captures.
    private var active: ActiveCapture?
    /// Capture IDs whose stop has already run; a repeat stop emits nothing (spec 4.1).
    private var stoppedCaptureIDs: Set<UUID> = []
    private var tapInstalled = false

    /// Per-capture state. A plain private class: it never crosses a concurrency boundary,
    /// because the results task reaches it through the @unchecked-Sendable engine.
    private final class ActiveCapture {
        let captureID: UUID
        var file: AVAudioFile?
        var sink: TapSink?
        var analyzer: SpeechAnalyzer?
        var analyzerInput: AsyncStream<AnalyzerInput>.Continuation?
        var resultsTask: Task<Void, Never>?
        var hasTranscriber = false
        var resultsFailed = false
        init(captureID: UUID, file: AVAudioFile) {
            self.captureID = captureID
            self.file = file
        }
    }

    init() {
        let (stream, continuation) = AsyncStream<CaptureEngineEvent>.makeStream()
        self.eventsStream = stream
        self.eventsContinuation = continuation
        observeNotifications()
    }

    // MARK: - Permissions

    /// Synchronous read for the composition root (LiveCapture.swift may not import AVFoundation).
    static func currentPermission() -> MicrophonePermission {
        mapPermission(AVAudioApplication.shared.recordPermission)
    }

    private static func mapPermission(_ permission: AVAudioApplication.recordPermission) -> MicrophonePermission {
        switch permission {
        case .undetermined: return .undetermined
        case .denied: return .denied
        case .granted: return .granted
        default: return .denied
        }
    }

    func microphonePermission() async -> MicrophonePermission {
        Self.mapPermission(AVAudioApplication.shared.recordPermission)
    }

    func requestMicrophonePermission() async -> MicrophonePermission {
        let granted = await AVAudioApplication.requestRecordPermission()
        return granted ? .granted : .denied
    }

    // MARK: - start

    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async {
        do {
            try await startUnsafe(captureID: captureID, audioURL: audioURL, route: route)
        } catch {
            cleanupAfterFailedStart(audioURL: audioURL)
            eventsContinuation.yield(.recorder(.engineStartFailed(captureID: captureID)))
        }
    }

    private func startUnsafe(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async throws {
        try session.setCategory(.record, mode: .spokenAudio)
        try session.setActive(true)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create exclusively with the recording protection class, then open; the open may
        // recreate the file, so re-apply the class afterwards.
        guard FileManager.default.createFile(atPath: audioURL.path, contents: nil,
                                             attributes: [.protectionKey: ProtectionPlan.whileRecording]) else {
            throw EngineError.fileCreateFailed
        }
        let file = try AVAudioFile(forWriting: audioURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
        ], commonFormat: .pcmFormatFloat32, interleaved: false)
        try FileManager.default.setAttributes([.protectionKey: ProtectionPlan.whileRecording],
                                              ofItemAtPath: audioURL.path)

        let capture = ActiveCapture(captureID: captureID, file: file)
        active = capture

        // Live transcriber (none for .audioOnly): one SpeechAnalyzer fed from the tap.
        if let module = SpeechModules.module(for: route, live: true) {
            // Typed optional so this compiles whether the SDK returns AVAudioFormat or AVAudioFormat?.
            let bestFormat: AVAudioFormat? = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
            guard let analyzerFormat = bestFormat else { throw EngineError.converterUnavailable }
            let converter: AVAudioConverter?
            if inputFormat == analyzerFormat {
                converter = nil     // identical formats (rate, channels, sample type); pass buffers through
            } else {
                guard let made = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
                    throw EngineError.converterUnavailable
                }
                converter = made
            }
            let (input, builder) = AsyncStream<AnalyzerInput>.makeStream()
            let analyzer = SpeechAnalyzer(modules: [module])
            try await analyzer.start(inputSequence: input)
            capture.analyzer = analyzer
            capture.analyzerInput = builder
            capture.hasTranscriber = true

            let sink = TapSink(file: file, converter: converter, builder: builder)
            capture.sink = sink
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                sink.consume(buffer)
            }
            tapInstalled = true

            engine.prepare()
            try engine.start()

            // Order matters (spec 4.1): both yields precede any result the task can produce.
            eventsContinuation.yield(.recorder(.engineStarted(captureID: captureID)))
            eventsContinuation.yield(.recorder(
                .transcriberRunStarted(captureID: captureID, run: 0, audioOffset: 0)))

            // The mapped stream (Sendable) is what the task captures, not the module.
            let results = SpeechModules.results(of: module)
            capture.resultsTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await result in results {
                        if result.isFinal {
                            self.eventsContinuation.yield(.recorder(.finalSegment(
                                captureID: captureID, run: 0,
                                segment: TranscriptSegment(text: result.text,
                                                           start: result.start,
                                                           end: result.end,
                                                           isFinal: true))))
                        } else {
                            self.eventsContinuation.yield(.volatile(captureID: captureID, text: result.text))
                        }
                    }
                } catch {
                    self.active?.resultsFailed = true
                }
            }
        } else {
            let sink = TapSink(file: file, converter: nil, builder: nil)
            capture.sink = sink
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                sink.consume(buffer)
            }
            tapInstalled = true

            engine.prepare()
            try engine.start()
            eventsContinuation.yield(.recorder(.engineStarted(captureID: captureID)))
        }
    }

    // MARK: - pause / resume

    /// Stops the engine; the file and the analyzer stay open (spec: locking is not a pause,
    /// and resume continues the same file).
    func pause(captureID: UUID) async {
        guard active?.captureID == captureID else { return }
        engine.pause()
    }

    func resume(captureID: UUID) async {
        guard active?.captureID == captureID else { return }
        do {
            try session.setActive(true)
            try engine.start()
        } catch {
            eventsContinuation.yield(.recorder(.engineFailed))
        }
    }

    // MARK: - stop

    /// Always emits engineStopped eventually, even if start never ran or failed (duration 0);
    /// idempotent per capture ID (spec 4.1). Emits engineStopped last.
    func stop(captureID: UUID) async {
        guard !stoppedCaptureIDs.contains(captureID) else { return }
        stoppedCaptureIDs.insert(captureID)
        guard let capture = active, capture.captureID == captureID else {
            eventsContinuation.yield(.recorder(.engineStopped(captureID: captureID, duration: 0)))
            return
        }

        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()

        if capture.hasTranscriber, let analyzer = capture.analyzer {
            capture.analyzerInput?.finish()
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                capture.resultsFailed = true
            }
            if let resultsTask = capture.resultsTask {
                await resultsTask.value     // drain the remaining finals before transcriberEnded
            }
            let writeFailed = capture.sink?.writeError ?? false
            let completed = !capture.resultsFailed && !writeFailed
            eventsContinuation.yield(.recorder(
                .transcriberEnded(captureID: captureID, run: 0, completed: completed)))
        }

        let duration: TimeInterval
        if let file = capture.file {
            let sampleRate = file.processingFormat.sampleRate
            duration = sampleRate > 0 ? Double(file.length) / sampleRate : 0
        } else {
            duration = 0
        }
        capture.file = nil        // releasing the AVAudioFile closes it
        capture.analyzer = nil
        capture.sink = nil
        self.active = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)

        eventsContinuation.yield(.recorder(.engineStopped(captureID: captureID, duration: duration)))
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let self, self.active != nil,
                  let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            switch type {
            case .began:
                self.eventsContinuation.yield(.recorder(.interruptionBegan))
            case .ended:
                let raw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: raw)
                self.eventsContinuation.yield(
                    .recorder(.interruptionEnded(shouldResume: options.contains(.shouldResume))))
            default:
                break
            }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self, self.active != nil else { return }
            self.eventsContinuation.yield(.recorder(.mediaServicesReset))
        }
    }

    // MARK: - Start failure

    private func cleanupAfterFailedStart(audioURL: URL) {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        active?.analyzerInput?.finish()
        active = nil              // closes the file
        // Delete the audio file only if it is zero bytes (spec 7).
        if let size = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int,
           size == 0 {
            try? FileManager.default.removeItem(at: audioURL)
        }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    var events: AsyncStream<CaptureEngineEvent> { eventsStream }

    private enum EngineError: Error {
        case fileCreateFailed, converterUnavailable
    }
}

/// The tap's only contact: writes each buffer to the audio file, then converts and forwards
/// it to the SpeechAnalyzer input. A write error is flagged, never thrown (a tap must not
/// throw). @unchecked Sendable: the tap delivers buffers on the audio thread; every property
/// is written from that one thread and read at stop.
final class TapSink: @unchecked Sendable {
    private let file: AVAudioFile
    private let converter: AVAudioConverter?
    private let builder: AsyncStream<AnalyzerInput>.Continuation?
    private(set) var writeError = false

    init(file: AVAudioFile, converter: AVAudioConverter?,
         builder: AsyncStream<AnalyzerInput>.Continuation?) {
        self.file = file
        self.converter = converter
        self.builder = builder
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        do {
            try file.write(from: buffer)
        } catch {
            writeError = true
            return
        }
        guard let builder else { return }
        if let converter {
            guard let converted = convert(buffer) else { return }
            builder.yield(AnalyzerInput(buffer: converted))
        } else {
            builder.yield(AnalyzerInput(buffer: buffer))
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }
        let outputFormat = converter.outputFormat
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }
        var providedInput = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if providedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            providedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}
