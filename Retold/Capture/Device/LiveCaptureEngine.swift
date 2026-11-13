import AVFoundation
import Foundation
import os
import Speech

/// The real CaptureEngine: AVAudioEngine tap -> AVAudioFile + SpeechAnalyzer (spec 7).
/// @unchecked Sendable justification: all mutable state is touched only inside the protocol
/// methods, which the coordinator awaits one at a time on one serial task. The tap touches only
/// its TapSink; the notification observers read only `activeFlag`, which is lock-protected.
final class LiveCaptureEngine: CaptureEngine, @unchecked Sendable {
    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()

    private let eventsStream: AsyncStream<CaptureEngineEvent>
    private let eventsContinuation: AsyncStream<CaptureEngineEvent>.Continuation

    /// State of the one in-flight capture; nil between captures.
    private var active: ActiveCapture?
    /// What the notification observers may read from any thread: is a capture active, and the
    /// input format its tap and file were built with.
    private let activeFlag = OSAllocatedUnfairLock<(active: Bool, format: AVAudioFormat?)>(
        uncheckedState: (false, nil))
    /// Capture IDs whose stop has already run; a repeat stop emits nothing (spec 4.1).
    private var stoppedCaptureIDs: Set<UUID> = []
    private var tapInstalled = false
    /// Which start step is running, so a failure names it (touched only by start/startUnsafe).
    private var startStep = "begin"
    private let startFailure = OSAllocatedUnfairLock<String?>(initialState: nil)
    /// Diagnostics for the capture in flight (CaptureStats.swift); nil unless CaptureStatsLog.enabled.
    private let stats = OSAllocatedUnfairLock<CaptureStats?>(initialState: nil)
    private let statsStart = OSAllocatedUnfairLock<UInt64>(initialState: 0)

    var lastStartFailure: String? { startFailure.withLock { $0 } }

    /// Per-capture state, touched only from the protocol methods and the capture's own results task.
    private final class ActiveCapture: @unchecked Sendable {
        let captureID: UUID
        var file: AVAudioFile?
        var sink: TapSink?
        /// The live transcriber (LiveTranscription.swift); nil for .audioOnly or a failed start.
        var transcription: LiveTranscription?
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
        startFailure.withLock { $0 = nil }
        do {
            try await startUnsafe(captureID: captureID, audioURL: audioURL, route: route)
        } catch {
            startFailure.withLock { $0 = "\(startStep): \(error)" }
            await cleanupAfterFailedStart(audioURL: audioURL)
            eventsContinuation.yield(.recorder(.engineStartFailed(captureID: captureID)))
        }
    }

    private func startUnsafe(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async throws {
        startStep = "session category"
        try configureSession()
        startStep = "session activate"
        try session.setActive(true)

        startStep = "input format"
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw EngineError.noInput
        }

        // Create exclusively (never truncate an existing recording) with the recording protection
        // class, then open; the open may recreate the file, so re-apply the class afterwards.
        guard !FileManager.default.fileExists(atPath: audioURL.path),
              FileManager.default.createFile(atPath: audioURL.path, contents: nil,
                                             attributes: [.protectionKey: ProtectionPlan.whileRecording]) else {
            throw EngineError.fileCreateFailed
        }
        startStep = "audio file"
        let file = try AVAudioFile(forWriting: audioURL, settings: CaptureAudioFile.settings(for: inputFormat),
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        try FileManager.default.setAttributes([.protectionKey: ProtectionPlan.whileRecording],
                                              ofItemAtPath: audioURL.path)

        let capture = ActiveCapture(captureID: captureID, file: file)
        active = capture

        // Live transcriber (none for .audioOnly): one SpeechAnalyzer fed from the tap.
        if let module = SpeechModules.module(for: route, live: true, tuning: .shipping) {
            do {
                capture.transcription = try await LiveTranscription.start(module: module,
                                                                          inputFormat: inputFormat,
                                                                          tuning: .shipping)
            } catch {
                // Audio first (PLAN section 1): a transcriber that cannot start (assets not yet
                // downloaded, an unsupported locale) must never cost the user the recording. Carry
                // on as audio-only; the file pass transcribes later, or the user files by title.
                capture.transcription = nil
            }
        }
        let transcription = capture.transcription

        startStep = "tap"
        let sink = TapSink(file: file, converter: transcription?.converter, builder: transcription?.input)
        capture.sink = sink
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            sink.consume(buffer)
        }
        tapInstalled = true

        startStep = "engine start"
        engine.prepare()
        try engine.start()
        activeFlag.withLockUnchecked { $0 = (true, inputFormat) }

        if CaptureStatsLog.enabled {
            statsStart.withLock { $0 = DispatchTime.now().uptimeNanoseconds }
            stats.withLock {
                $0 = CaptureStats(startedAt: Date(), route: route.journalTag, inputFormat: "\(inputFormat)",
                                  transcriberStarted: transcription != nil)
            }
        } else {
            stats.withLock { $0 = nil }
        }

        // Order matters (spec 4.1): both yields precede any result the task can produce.
        eventsContinuation.yield(.recorder(.engineStarted(captureID: captureID)))
        guard let transcription else { return }
        eventsContinuation.yield(.recorder(
            .transcriberRunStarted(captureID: captureID, run: 0, audioOffset: 0)))

        let continuation = eventsContinuation
        let stats = self.stats
        let statsStart = self.statsStart
        transcription.startResults { result in
            stats.withLock { record in
                guard record != nil else { return }
                let started = statsStart.withLock { $0 }
                let after = Double(DispatchTime.now().uptimeNanoseconds &- started) / 1e9
                if result.isFinal {
                    record?.finals += 1
                    if record?.firstFinalAfter == nil { record?.firstFinalAfter = after }
                } else {
                    record?.volatiles += 1
                    if record?.firstVolatileAfter == nil { record?.firstVolatileAfter = after }
                }
            }
            if result.isFinal {
                continuation.yield(.recorder(.finalSegment(
                    captureID: captureID, run: 0,
                    segment: TranscriptSegment(text: result.text,
                                               start: result.start,
                                               end: result.end,
                                               isFinal: true))))
            } else {
                continuation.yield(.volatile(captureID: captureID, text: result.text))
            }
        }
    }

    /// iOS rejects some category and mode pairs with OSStatus -50, and which pairs it accepts can
    /// differ by device and OS. Try the preferred pair, then pairs that are always valid for recording.
    private func configureSession() throws {
        let attempts: [(AVAudioSession.Category, AVAudioSession.Mode)] = [
            (.record, .spokenAudio),
            (.playAndRecord, .spokenAudio),
            (.playAndRecord, .default),
            (.record, .default),
        ]
        var firstError: Error?
        for (category, mode) in attempts {
            do {
                try session.setCategory(category, mode: mode)
                // Without this iOS mutes haptics while an input session is active, so the
                // start/stop feedback on the recorder would never be felt. Best effort.
                try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
                return
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        throw firstError ?? EngineError.noInput
    }

    // MARK: - pause / resume

    /// Pauses the engine; the file and the analyzer stay open (resume continues the same file).
    func pause(captureID: UUID) async {
        guard active?.captureID == captureID else { return }
        engine.pause()
    }

    func resume(captureID: UUID) async {
        guard active?.captureID == captureID else { return }
        // The tap, file and converter were built for the start format; a route change during the
        // interruption (e.g. Bluetooth HFP) would make every write fail silently. End visibly instead.
        let startFormat = activeFlag.withLockUnchecked { $0.format }
        do {
            try session.setActive(true)
            guard engine.inputNode.outputFormat(forBus: 0) == startFormat else {
                throw EngineError.inputFormatChanged
            }
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
        activeFlag.withLockUnchecked { $0 = (false, nil) }

        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        let stopUptime = DispatchTime.now().uptimeNanoseconds
        let finalsBeforeStop = stats.withLock { $0?.finals ?? 0 }

        var transcriberCompleted: Bool?
        if let transcription = capture.transcription {
            // Finalizes through the end of input and drains the remaining finals before transcriberEnded.
            let completed = await transcription.finish(flushing: capture.sink)
            let writeFailed = capture.sink?.writeError ?? false
            transcriberCompleted = completed && !writeFailed
            eventsContinuation.yield(.recorder(
                .transcriberEnded(captureID: captureID, run: 0, completed: completed && !writeFailed)))
        }

        // Close explicitly so the m4a is finalized before the importer or duration probe reads it.
        let duration: TimeInterval
        if let file = capture.file {
            let sampleRate = file.processingFormat.sampleRate
            duration = sampleRate > 0 ? Double(file.length) / sampleRate : 0
            file.close()
        } else {
            duration = 0
        }
        if var record = stats.withLock({ $0 }) {
            let now = DispatchTime.now().uptimeNanoseconds
            let started = statsStart.withLock { $0 }
            if let sink = capture.sink {
                let timing = sink.bufferTiming
                record.buffers = timing.count
                record.maxBufferGap = timing.maxGap
                record.gapsOverOneSecond = timing.gapsOverOneSecond
                record.convertDrops = sink.convertDrops
                record.writeError = sink.writeError
            }
            record.finalsAfterStop = record.finals - finalsBeforeStop
            record.recordedSeconds = duration
            record.wallSeconds = Double(stopUptime &- started) / 1e9
            record.stopToDone = Double(now &- stopUptime) / 1e9
            record.transcriberCompleted = transcriberCompleted
            CaptureStatsLog.append(record)
            stats.withLock { $0 = nil }
        }

        capture.file = nil
        capture.transcription = nil
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
            guard let self, self.activeFlag.withLockUnchecked({ $0.active }),
                  let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            switch type {
            case .began:
                self.stats.withLock { $0?.interruptions += 1 }
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
            guard let self, self.activeFlag.withLockUnchecked({ $0.active }) else { return }
            self.stats.withLock { $0?.mediaResets += 1 }
            self.eventsContinuation.yield(.recorder(.mediaServicesReset))
        }
        // A route change mid-capture (headset, Bluetooth HFP) can change the input format; the
        // tap and file cannot follow it, so end the capture visibly rather than lose audio silently.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            let state = self.activeFlag.withLockUnchecked { $0 }
            guard state.active else { return }
            let sameFormat = self.engine.inputNode.outputFormat(forBus: 0) == state.format
            let running = self.engine.isRunning
            self.stats.withLock { record in
                record?.configChanges += 1
                if sameFormat { record?.configChangesSameFormat += 1 }
                record?.engineRunningAfterConfigChange.append(running)
            }
            guard !sameFormat else { return }
            self.eventsContinuation.yield(.recorder(.engineFailed))
        }
    }

    // MARK: - Start failure

    private func cleanupAfterFailedStart(audioURL: URL) async {
        activeFlag.withLockUnchecked { $0 = (false, nil) }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        if let transcription = active?.transcription {
            await transcription.cancel()
        }
        active?.file?.close()
        active = nil
        // Delete the audio file only if it is zero bytes (spec 7).
        if let size = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int,
           size == 0 {
            try? FileManager.default.removeItem(at: audioURL)
        }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    var events: AsyncStream<CaptureEngineEvent> { eventsStream }

    private enum EngineError: Error {
        case fileCreateFailed, inputFormatChanged, noInput
    }
}
