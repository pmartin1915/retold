import Foundation
import Observation
import SwiftData

// Owns the recorder loop: reduces engine events through RecorderMachine, runs journal effects
// synchronously in a FIFO drain, and hands engine effects to one serial task so a pause can never
// overtake a start. The store is touched only inside importJournals/retranscribePending and only
// while protectedDataAvailable.

@MainActor @Observable
final class CaptureCoordinator {
    private(set) var state: RecorderState
    private(set) var liveText: String = ""        // UI only: journaled finals joined by " " + current volatile; reset at startEngine
    private(set) var journalError: Error?         // last journal failure, for the UI
    private(set) var processedEventCount = 0      // incremented after each handled event (tests)
    private(set) var lastImport: JournalImporter.Report?

    let files: CaptureFiles
    let importer: JournalImporter

    @ObservationIgnored private let engine: any CaptureEngine
    @ObservationIgnored private let fileTranscriber: any FileTranscriber
    @ObservationIgnored private let routeProvider: @Sendable () async -> TranscriptionRoute
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let inbox: CaptureLaunchInbox
    @ObservationIgnored private let makeWriter: (CaptureFiles, UUID) throws -> any JournalAppending
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let newID: () -> UUID

    @ObservationIgnored private var effectQueue: [RecorderEffect] = []
    @ObservationIgnored private var isDraining = false
    @ObservationIgnored private var writers: [UUID: any JournalAppending] = [:]
    @ObservationIgnored private let effectContinuation: AsyncStream<RecorderEffect>.Continuation
    @ObservationIgnored private var outstandingEngineCalls = 0
    @ObservationIgnored private var filePassTask: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false
    @ObservationIgnored private var journaledFinalTexts: [String] = []
    @ObservationIgnored private var currentVolatile: String = ""
    @ObservationIgnored private var degradedCaptures: Set<UUID> = []   // a journal append failed

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
         newID: @escaping () -> UUID = UUID.init) {
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
    private var activeCaptureID: UUID? {
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
            send(recorderEvent)
        case .volatile(_, let text):
            currentVolatile = text
            rebuildLiveText()
        }
    }

    /// reduce, enqueue effects, drain.
    func send(_ event: RecorderEvent) {
        let (newState, effects) = RecorderMachine.reduce(state, event, now: now(), newID: newID)
        state = newState
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
                        journaledFinalTexts.append(text)
                        rebuildLiveText()
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
                send(.engineStartFailed(captureID: captureID))
                outstandingEngineCalls -= 1
                return
            }
            journaledFinalTexts = []
            currentVolatile = ""
            liveText = ""
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

    private func rebuildLiveText() {
        let joined = journaledFinalTexts.joined(separator: " ")
        liveText = joined.isEmpty ? currentVolatile
            : (currentVolatile.isEmpty ? joined : joined + " " + currentVolatile)
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

    /// In-app Record button: refresh route, then send.
    func startCapture(answering: UUID?) async {
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
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let captures = try? context.fetch(FetchDescriptor<Capture>()) else { return }
        let candidates = captures
            .filter { [TranscriptionStatus.live, .pending, .fromFile].contains($0.transcriptionStatus) }
            .filter { $0.id != activeCaptureID }
            .filter { FileManager.default.fileExists(atPath: files.audioURL(for: $0.id).path) }
        for capture in candidates {
            guard state.protectedDataAvailable else { return }  // re-checked after every await
            if !capture.corrections.isEmpty { continue }     // correction indices point at current segments
            let route = await routeProvider()
            guard state.protectedDataAvailable else { return }
            if case .audioOnly = route { continue }          // stays .live for a later pass
            let current = capture.transcript
            do {
                try capture.updateTranscript(current, status: .fromFile)
                var segments: [TranscriptSegment] = []
                for try await segment in fileTranscriber.transcribe(
                    audioURL: files.audioURL(for: capture.id), route: route
                ) {
                    segments.append(segment)
                }
                if segments.isEmpty {
                    if current.isEmpty {
                        try capture.completeTranscript([])   // silence is a complete transcript
                    } else {
                        try capture.updateTranscript(current, status: .failed)
                    }
                } else {
                    try capture.completeTranscript(segments) // the file is authoritative
                }
                // The phone may have locked during the transcription: never touch the store then.
                guard state.protectedDataAvailable else { context.rollback(); return }
                try context.save()
            } catch {
                guard state.protectedDataAvailable else { context.rollback(); return }
                try? capture.updateTranscript(current, status: .failed)  // keep the partial
                try? context.save()
            }
        }
    }
}
