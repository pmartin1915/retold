import Foundation
import Observation
import os
import SwiftData

// Owns the recorder loop: reduces engine events through RecorderMachine, runs journal effects
// synchronously in a FIFO drain, and hands engine effects to one serial task so a pause can never
// overtake a start. The store is touched only inside importJournals/retranscribePending and only
// while protectedDataAvailable.

/// §7a: recorded-time thresholds for one capture. Time spent interrupted does not count.
/// Injectable so tests can run the real timer in milliseconds.
struct CaptureLengthLimits: Equatable, Sendable {
    var warning: TimeInterval
    var limit: TimeInterval

    static let standard = CaptureLengthLimits(warning: 20 * 60, limit: 30 * 60)
}

@MainActor @Observable
final class CaptureCoordinator {
    private(set) var state: RecorderState
    /// UI only, reset at startEngine. comeup run 3: finals and the volatile tail are kept apart so a
    /// volatile result (many per second) changes one short string instead of rebuilding the whole
    /// transcript, and the recorder can show tentative words differently from settled ones.
    private(set) var liveFinalText: String = ""   // journaled finals joined by " ", appended in place
    private(set) var liveVolatileText: String = ""  // the current volatile result
    /// Journaled finals joined by " " + current volatile (the pre-run-3 single string; tests).
    var liveText: String {
        liveFinalText.isEmpty ? liveVolatileText
            : (liveVolatileText.isEmpty ? liveFinalText : liveFinalText + " " + liveVolatileText)
    }
    private(set) var journalError: Error?         // last journal failure, for the UI
    private(set) var startFailure: String?        // why the last start failed, for the UI alert
    private(set) var processedEventCount = 0      // incremented after each handled event (tests)
    private(set) var lastImport: JournalImporter.Report?
    private(set) var lengthWarning = false        // §7a: the recorder screen's banner, from limits.warning

    let files: CaptureFiles
    let importer: JournalImporter

    @ObservationIgnored private let engine: any CaptureEngine
    @ObservationIgnored private let fileTranscriber: any FileTranscriber
    @ObservationIgnored private let routeProvider: @Sendable () async -> TranscriptionRoute
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let inbox: CaptureLaunchInbox
    @ObservationIgnored private var startInFlight = false
    @ObservationIgnored private let makeWriter: (CaptureFiles, UUID) throws -> any JournalAppending
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let newID: () -> UUID
    @ObservationIgnored private let lengthLimits: CaptureLengthLimits
    @ObservationIgnored private let whisperTimeLimit: @Sendable (TimeInterval) -> TimeInterval
    /// The running Whisper pass, if any: its task and its result slot (non-nil once it has unloaded).
    @ObservationIgnored private var runningWhisper: (task: Task<Void, Never>,
                                                     outcome: OSAllocatedUnfairLock<Result<[TranscriptSegment], Error>?>)?

    @ObservationIgnored private var effectQueue: [RecorderEffect] = []
    @ObservationIgnored private var isDraining = false
    @ObservationIgnored private var writers: [UUID: any JournalAppending] = [:]
    @ObservationIgnored private let effectContinuation: AsyncStream<RecorderEffect>.Continuation
    @ObservationIgnored private var outstandingEngineCalls = 0
    @ObservationIgnored private var filePassTask: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false
    @ObservationIgnored private var degradedCaptures: Set<UUID> = []   // a journal append failed
    @ObservationIgnored private var recordedBeforeSegment: TimeInterval = 0   // closed .recording stretches
    @ObservationIgnored private var segmentStart: Date?                       // the open .recording stretch
    @ObservationIgnored private var lengthTask: Task<Void, Never>?
    @ObservationIgnored private var hasRun = false

    init(engine: any CaptureEngine,
         fileTranscriber: any FileTranscriber,
         routeProvider: @escaping @Sendable () async -> TranscriptionRoute,
         files: CaptureFiles,
         importer: JournalImporter,
         container: ModelContainer,
         initialPermission: MicrophonePermission,
         protectedDataAvailable: Bool,
         inbox: CaptureLaunchInbox = .shared,
         makeWriter: @escaping (CaptureFiles, UUID) throws -> any JournalAppending,
         now: @escaping () -> Date = Date.init,
         newID: @escaping () -> UUID = UUID.init,
         lengthLimits: CaptureLengthLimits = .standard,
         whisperTimeLimit: @escaping @Sendable (TimeInterval) -> TimeInterval = { WhisperPassLimits.timeLimit(duration: $0) }) {
        self.engine = engine
        self.fileTranscriber = fileTranscriber
        self.routeProvider = routeProvider
        self.files = files
        self.importer = importer
        self.container = container
        self.inbox = inbox
        self.makeWriter = makeWriter
        self.now = now
        self.newID = newID
        self.lengthLimits = lengthLimits
        self.whisperTimeLimit = whisperTimeLimit
        self.state = RecorderState(permission: initialPermission,
                                   protectedDataAvailable: protectedDataAvailable)

        let (stream, continuation) = AsyncStream<RecorderEffect>.makeStream()
        self.effectContinuation = continuation
        // One serial consumer: engine effects are awaited one at a time, in order.
        Task { [weak self] in
            for await effect in stream {
                guard let self else { return }
                await self.performEngineEffect(effect)
            }
        }

        inbox.onRequest = { [weak self] in
            Task { await self?.drainLaunchInbox() }
        }
    }

    /// The capture ID of the active phase, if any (excluded from import and the file pass).
    var activeCaptureID: UUID? {
        switch state.phase {
        case .starting(let id, _), .recording(let id), .interrupted(let id),
             .stopping(let id, _), .aborting(let id):
            return id
        case .idle, .blocked:
            return nil
        }
    }

    // MARK: - Event intake

    /// files.prepare(); then, if protectedDataAvailable, one import + file pass; then
    /// `for await e in engine.events { handle(e) }`. Returns when the stream finishes.
    func run() async {
        // engine.events has a single consumer; a re-created view's .task must not start a second loop.
        guard !hasRun else { return }
        hasRun = true
        try? files.prepare()
        if state.protectedDataAvailable {
            lastImport = importer.importAll(into: container, excluding: activeCaptureID)
            // In the background: an Action press during a long launch pass must not wait on it.
            kickFilePass()
        }
        for await event in engine.events {
            handle(event)
        }
    }

    func handle(_ event: CaptureEngineEvent) {
        switch event {
        case .recorder(let recorderEvent):
            if case .engineStartFailed = recorderEvent {
                startFailure = engine.lastStartFailure ?? "unknown"
            }
            send(recorderEvent)
        case .volatile(_, let text):
            liveVolatileText = text
        }
    }

    /// reduce, enqueue effects, drain.
    func send(_ event: RecorderEvent) {
        let oldPhase = state.phase
        let (newState, effects) = RecorderMachine.reduce(state, event, now: now(), newID: newID)
        state = newState
        WhisperModelGate.captureActive = activeCaptureID != nil
        updateLengthTimer(from: oldPhase)
        processedEventCount += 1
        effectQueue.append(contentsOf: effects)
        drain()
    }

    /// Awaits until the effect queue is empty and every engine call has returned (tests).
    func drainEffects() async {
        var iterations = 0
        while (isDraining || !effectQueue.isEmpty || outstandingEngineCalls > 0) && iterations < 10_000 {
            await Task.yield()
            iterations += 1
        }
    }

    // MARK: - Effect queue

    /// FIFO drain. A send made during a drain only enqueues. Journal effects run synchronously;
    /// engine effects are handed to the one serial effect task.
    private func drain() {
        guard !isDraining else { return }
        isDraining = true
        while !effectQueue.isEmpty {
            let effect = effectQueue.removeFirst()
            switch effect {
            case .openJournal(let captureID):
                do {
                    writers[captureID] = try makeWriter(files, captureID)
                } catch {
                    // The audio survives and pass 2 adopts it; stop cleanly.
                    journalError = error
                    send(.tapStop)
                }
            case .journal(var record):
                guard let writer = writers[record.captureID] else { continue }
                if record.kind == .transcriberEnded, degradedCaptures.contains(record.captureID) {
                    record.completed = false     // a segment may be missing: force the file pass
                }
                do {
                    try writer.append(record)
                    if record.kind == .segment, let text = record.text {
                        liveFinalText = liveFinalText.isEmpty ? text : liveFinalText + " " + text
                    }
                } catch {
                    journalError = error        // the audio is the record; recording continues
                    degradedCaptures.insert(record.captureID)
                }
            case .closeJournal(let captureID):
                writers[captureID]?.close()
                writers[captureID] = nil
                degradedCaptures.remove(captureID)
            case .importJournals:
                guard state.protectedDataAvailable else { continue }
                lastImport = importer.importAll(into: container, excluding: activeCaptureID)
                kickFilePass()
            case .startEngine, .pauseEngine, .resumeEngine, .stopEngine:
                outstandingEngineCalls += 1
                effectContinuation.yield(effect)
            }
        }
        isDraining = false
    }

    private func performEngineEffect(_ effect: RecorderEffect) async {
        switch effect {
        case .startEngine(let captureID, let route):
            do {
                try files.prepare()
            } catch {
                journalError = error
                startFailure = String(describing: error)
                send(.engineStartFailed(captureID: captureID))
                outstandingEngineCalls -= 1
                return
            }
            // Whisper pass spec section 4: a running pass is cancelled and given a few seconds to
            // unload before the microphone starts. Audio first: the recording starts regardless.
            await releaseWhisper(upTo: .seconds(3))
            liveFinalText = ""
            liveVolatileText = ""
            await engine.start(captureID: captureID, audioURL: files.audioURL(for: captureID), route: route)
        case .pauseEngine(let captureID):
            await engine.pause(captureID: captureID)
        case .resumeEngine(let captureID):
            await engine.resume(captureID: captureID)
        case .stopEngine(let captureID):
            await engine.stop(captureID: captureID)
        case .openJournal, .journal, .closeJournal, .importJournals:
            break   // handled synchronously in the drain
        }
        outstandingEngineCalls -= 1
    }

    // MARK: - Length limit (§7a)

    private static func isRecording(_ phase: RecorderPhase) -> Bool {
        if case .recording = phase { return true }
        return false
    }

    /// Counts recorded time only: a stretch opens on entering .recording and closes on leaving it,
    /// so .interrupted time does not count. A new capture (.starting) resets the count and the banner.
    private func updateLengthTimer(from oldPhase: RecorderPhase) {
        let wasRecording = Self.isRecording(oldPhase)
        let isRecording = Self.isRecording(state.phase)
        if case .starting = state.phase {
            recordedBeforeSegment = 0
            segmentStart = nil
            lengthWarning = false
        }
        if wasRecording && !isRecording {
            if let start = segmentStart {
                recordedBeforeSegment += max(0, now().timeIntervalSince(start))
            }
            segmentStart = nil
            lengthTask?.cancel()
            lengthTask = nil
        }
        if !wasRecording && isRecording {
            segmentStart = now()
            scheduleLengthTimer()
        }
        if state.phase == .idle {
            lengthWarning = false
        }
    }

    /// One task per .recording stretch, sleeping only for the time left. Cancelled when the stretch closes.
    private func scheduleLengthTimer() {
        lengthTask?.cancel()
        let recorded = recordedBeforeSegment
        let limits = lengthLimits
        lengthTask = Task { [weak self] in
            let untilWarning = limits.warning - recorded
            if untilWarning > 0 {
                try? await Task.sleep(for: .seconds(untilWarning))
                if Task.isCancelled { return }
            }
            guard let self else { return }
            self.lengthWarning = true
            let untilLimit = limits.limit - max(recorded, limits.warning)
            if untilLimit > 0 {
                try? await Task.sleep(for: .seconds(untilLimit))
                if Task.isCancelled { return }
            }
            self.send(.timeLimitReached)
        }
    }

    // MARK: - Launch inbox and capture start

    /// Refreshes the permission, the route (routeProvider), then takes the inbox; if a start was
    /// pending, sends startRequested(answering: nil). Called on sceneDidBecomeActive and by the
    /// inbox's onRequest hook.
    func drainLaunchInbox() async {
        send(.permissionChanged(await engine.microphonePermission()))
        send(.routeChanged(await routeProvider()))
        if inbox.take() {
            send(.startRequested(answering: nil))
        }
    }

    /// The UI shows startFailure once, then clears it.
    func clearStartFailure() {
        startFailure = nil
    }

    /// In-app Record button: refresh route, then send.
    func startCapture(answering: UUID?) async {
        // The route lookup suspends. A second tap in that gap would reach the reducer as a second
        // startRequested, which §7a reads as "stop as soon as it starts": the capture would start
        // and end at once. In-app taps are single-flight; the Action button sends the event directly.
        guard !startInFlight else { return }
        startInFlight = true
        defer { startInFlight = false }
        send(.routeChanged(await routeProvider()))
        send(.startRequested(answering: answering))
    }

    // MARK: - File pass

    /// File pass over every Capture with status .live, .pending or .fromFile whose audio exists,
    /// excluding the active capture. Single-flight: a call made while the pass runs sets
    /// rerunRequested and the running pass loops once more. Only while protectedDataAvailable.
    func retranscribePending() async {
        kickFilePass()
        await awaitFilePass()
    }

    /// Synchronous single-flight start: requests a (re)run and creates the pass task if none is
    /// running. The task clears filePassTask itself, with no suspension between its last rerun
    /// check and the clear, so a request can never be lost.
    private func kickFilePass() {
        guard state.protectedDataAvailable else { return }
        rerunRequested = true
        guard filePassTask == nil else { return }
        filePassTask = Task { [weak self] in
            guard let self else { return }
            while self.rerunRequested && self.state.protectedDataAvailable {
                self.rerunRequested = false
                await self.performOneFilePass()
            }
            self.filePassTask = nil
        }
    }

    /// Awaits the running file pass, if any (tests; launch runs the pass in the background).
    func awaitFilePass() async {
        while let task = filePassTask { await task.value }
    }

    private func performOneFilePass() async {
        guard state.protectedDataAvailable else { return }
        let scan = ModelContext(container)
        guard let captures = try? scan.fetch(FetchDescriptor<Capture>()) else { return }
        // Whisper pass spec section 2: marked captures (Apple's live run completed) get the Whisper
        // pass and never the Apple file pass; everything else is unchanged.
        let ledger = importer.ledger
        let waiting = captures.filter { $0.transcriptionStatus == .live && ledger?.isMarked($0.id) == true }
        ledger?.prune(keeping: Set(waiting.map(\.id)))
        let marked = waiting.map { (id: $0.id, duration: $0.duration) }
        let markedIDs = Set(marked.map(\.id))
        for item in marked {
            guard state.protectedDataAvailable else { return }
            await performWhisperPass(captureID: item.id, duration: item.duration)
        }
        let candidateIDs = captures
            .filter { [TranscriptionStatus.live, .pending, .fromFile].contains($0.transcriptionStatus) }
            .filter { !markedIDs.contains($0.id) }
            .filter { $0.id != activeCaptureID }
            .filter { $0.corrections.isEmpty }               // correction indices point at current segments
            .filter { FileManager.default.fileExists(atPath: files.audioURL(for: $0.id).path) }
            .map(\.id)
        for captureID in candidateIDs {
            guard state.protectedDataAvailable else { return }  // re-checked after every await
            let route = await routeProvider()
            guard state.protectedDataAvailable else { return }
            if case .audioOnly = route { continue }          // stays .live for a later pass
            var segments: [TranscriptSegment]? = []
            do {
                for try await segment in fileTranscriber.transcribe(
                    audioURL: files.audioURL(for: captureID), route: route
                ) {
                    segments?.append(segment)
                }
            } catch {
                segments = nil
            }
            // The phone may have locked during the transcription: never touch the store then.
            guard state.protectedDataAvailable else { return }
            Self.applyFilePassResult(captureID: captureID, segments: segments, in: container)
        }
    }

    /// Writes one file-pass result to the capture, fetched in a fresh context with no suspension
    /// between the fetch and the save. A capture object held across the transcription's awaits would
    /// be a stale snapshot, and saving it would overwrite a main-context write made meanwhile, such as
    /// R7b's AnswerAttacher setting capture.episode. Every writer is on the main actor, so nothing
    /// interleaves here. `segments` nil = the transcription threw. Does nothing unless the capture is
    /// still .live, .pending or .fromFile with no corrections.
    static func applyFilePassResult(captureID: UUID, segments: [TranscriptSegment]?, in container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let wantedID = captureID
        var descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == wantedID })
        descriptor.fetchLimit = 1
        guard let capture = (try? context.fetch(descriptor))?.first,
              [TranscriptionStatus.live, .pending, .fromFile].contains(capture.transcriptionStatus),
              capture.corrections.isEmpty
        else { return }
        let current = capture.transcript
        do {
            if let segments, !segments.isEmpty {
                try capture.completeTranscript(segments)     // the file is authoritative
            } else if segments != nil, current.isEmpty {
                try capture.completeTranscript([])           // silence is a complete transcript
            } else {
                try capture.updateTranscript(current, status: .failed)  // keep the partial
            }
            try context.save()
        } catch {
            context.rollback()
        }
    }

    // MARK: - Whisper pass (docs/WHISPER-PASS-SPEC.md)

    private enum WhisperWait {
        case finished(Result<[TranscriptSegment], Error>)
        case interrupted     // a capture started or the phone locked: leave it marked
        case timedOut
    }

    /// One marked capture: decides the fallbacks that need no model, then runs Whisper bounded by
    /// time, the active-capture rule and the lock, and writes the outcome (spec section 3).
    private func performWhisperPass(captureID: UUID, duration: TimeInterval) async {
        guard let ledger = importer.ledger else { return }
        guard let pass = importer.afterStopPass, pass.isReady(),
              ledger.attempts(captureID) < WhisperPassLimits.attemptCap,
              !Self.hasCorrections(captureID, in: container),
              (pass.availableMemoryMB() ?? Int.max) >= WhisperPassLimits.requiredMemoryMB
        else {
            Self.applyWhisperPassResult(captureID: captureID, whisper: nil, ledger: ledger, in: container)
            return
        }
        // Never load 674 MB beside a live recording; the import at its Stop kicks the pass again.
        guard activeCaptureID == nil else { return }

        ledger.beginAttempt(captureID)
        let audioURL = files.audioURL(for: captureID)
        let outcome = OSAllocatedUnfairLock<Result<[TranscriptSegment], Error>?>(initialState: nil)
        let task = Task.detached {
            let result: Result<[TranscriptSegment], Error>
            do {
                result = .success(try await pass.transcribe(audioURL: audioURL))
            } catch {
                result = .failure(error)
            }
            outcome.withLock { $0 = result }
        }

        let deadline = ContinuousClock.now + .seconds(whisperTimeLimit(duration))
        runningWhisper = (task, outcome)
        defer { runningWhisper = nil }
        switch await waitForWhisper(outcome, until: deadline) {
        case .finished(let result):
            guard state.protectedDataAvailable else {
                ledger.giveBack(captureID)
                return
            }
            Self.applyWhisperPassResult(captureID: captureID, whisper: try? result.get(),
                                        ledger: ledger, in: container)
        case .interrupted:
            task.cancel()
            ledger.giveBack(captureID)
            await task.value      // the pass unloads the model on cancellation
        case .timedOut:
            task.cancel()
            if state.protectedDataAvailable {
                Self.applyWhisperPassResult(captureID: captureID, whisper: nil, ledger: ledger, in: container)
            } else {
                ledger.giveBack(captureID)
            }
            await task.value      // never two models resident: wait for the unload
        }
    }

    /// Cancels the running Whisper pass and waits until it has unloaded, at most `limit`.
    private func releaseWhisper(upTo limit: Duration) async {
        guard let running = runningWhisper else { return }
        running.task.cancel()
        let deadline = ContinuousClock.now + limit
        while running.outcome.withLock({ $0 }) == nil && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Polls the running pass every 50 ms: its result, a capture starting, the lock, the deadline.
    private func waitForWhisper(_ outcome: OSAllocatedUnfairLock<Result<[TranscriptSegment], Error>?>,
                                until deadline: ContinuousClock.Instant) async -> WhisperWait {
        while true {
            // Interruption first (Sol review of PR #40): a recording start cancels the pass, and the
            // CancellationError it then publishes must not read as a finished pass that keeps Apple's.
            // The reducer enters .starting synchronously, before the start effect cancels anything.
            if activeCaptureID != nil || !state.protectedDataAvailable { return .interrupted }
            if let result = outcome.withLock({ $0 }) { return .finished(result) }
            if ContinuousClock.now >= deadline { return .timedOut }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func hasCorrections(_ captureID: UUID, in container: ModelContainer) -> Bool {
        let wantedID = captureID
        var descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == wantedID })
        descriptor.fetchLimit = 1
        let capture = (try? ModelContext(container).fetch(descriptor))?.first
        return !(capture?.corrections.isEmpty ?? true)
    }

    /// Completes a marked capture: with Whisper's words when `whisper` is accepted and the capture has
    /// no corrections, otherwise with Apple's (never .failed: Apple's run completed). Fresh context,
    /// no suspension between fetch and save (as applyFilePassResult). Does nothing to a capture that
    /// is no longer .live. The marker goes once the capture is complete or gone.
    static func applyWhisperPassResult(captureID: UUID, whisper: [TranscriptSegment]?,
                                       ledger: WhisperPassLedger, in container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let wantedID = captureID
        var descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == wantedID })
        descriptor.fetchLimit = 1
        // A fetch error is not absence: keep the marker, so the capture never falls to the Apple file pass.
        guard let fetched = try? context.fetch(descriptor) else { return }
        guard let capture = fetched.first, capture.transcriptionStatus == .live else {
            ledger.remove(captureID)
            return
        }
        let apple = capture.transcript
        var kept = apple
        if let whisper, capture.corrections.isEmpty, WhisperPassLimits.accepts(whisper: whisper, apple: apple) {
            kept = whisper
        }
        do {
            try capture.completeTranscript(kept)
            try context.save()
            ledger.remove(captureID)
        } catch {
            context.rollback()       // stays marked; the attempt cap ends a repeat
        }
    }
}
