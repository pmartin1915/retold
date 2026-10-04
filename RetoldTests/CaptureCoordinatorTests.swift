import Foundation
import SwiftData
import XCTest
@testable import Retold

/// The coordinator driven by mocks: effect ordering, the store guard, single-flight file pass,
/// launch inbox, and the week-1 gate testLockMidCaptureLosesNothing
/// (docs/R6-RECORDER-SPEC.md §5.2 and §6).
final class CaptureCoordinatorTests: XCTestCase {
    private let captureID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // No setUp/tearDown overrides (non-isolated class; tests are individually @MainActor).

    private func makeFiles() -> CaptureFiles {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-coordinator-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return CaptureFiles(root: root)
    }

    private struct Harness {
        let coordinator: CaptureCoordinator
        let engine: MockCaptureEngine
        let transcriber: MockFileTranscriber
        let protector: MockFileProtector
        let files: CaptureFiles
        let container: ModelContainer
        let inbox: CaptureLaunchInbox
    }

    @MainActor
    private func makeHarness(
        protectedDataAvailable: Bool = true,
        initialPermission: MicrophonePermission = .granted,
        route: TranscriptionRoute = .audioOnly(.notChecked),
        makeWriter: ((CaptureFiles, UUID) throws -> any JournalAppending)? = nil,
        now: @escaping () -> Date = Date.init,
        newID: (() -> UUID)? = nil
    ) throws -> Harness {
        // Every test drives events for `captureID`, so the reducer must mint that ID by default.
        let newID = newID ?? { [captureID] in captureID }
        let files = makeFiles()
        try files.prepare()
        let container = try RetoldSchema.makeInMemoryContainer()
        let engine = MockCaptureEngine()
        let transcriber = MockFileTranscriber()
        let probe = MockDurationProbe()
        let protector = MockFileProtector()
        let inbox = CaptureLaunchInbox()
        let importer = JournalImporter(files: files, durationProbe: probe, protector: protector)
        let writer: (CaptureFiles, UUID) throws -> any JournalAppending = makeWriter ?? { files, id in
            try JournalWriter(files: files, captureID: id, protector: protector)
        }
        let provider: @Sendable () async -> TranscriptionRoute = { route }
        let coordinator = CaptureCoordinator(
            engine: engine,
            fileTranscriber: transcriber,
            routeProvider: provider,
            files: files,
            importer: importer,
            container: container,
            initialPermission: initialPermission,
            protectedDataAvailable: protectedDataAvailable,
            inbox: inbox,
            makeWriter: writer,
            now: now,
            newID: newID
        )
        return Harness(coordinator: coordinator, engine: engine, transcriber: transcriber,
                       protector: protector, files: files, container: container, inbox: inbox)
    }

    private func fetchCaptures(in container: ModelContainer) throws -> [Capture] {
        try ModelContext(container).fetch(FetchDescriptor<Capture>())
    }

    private func fetchCapture(_ id: UUID, in container: ModelContainer) throws -> Capture? {
        let cid = id
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        return try context.fetch(descriptor).first
    }

    // MARK: - The week-1 gate

    @MainActor
    func testLockMidCaptureLosesNothing() async throws {
        let harness = try makeHarness(
            route: .speech(localeID: "en_US"),
            newID: { [captureID] in captureID })
        let segments = [
            TranscriptSegment(text: "one", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "two", start: 2, end: 4, isFinal: true),
            TranscriptSegment(text: "three", start: 4, end: 6, isFinal: true),
            TranscriptSegment(text: "four", start: 6, end: 8, isFinal: true),
        ]

        // 1. Start while unlocked (startCapture refreshes the route first, so .begin says speech).
        await harness.coordinator.startCapture(answering: nil)
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        // Create the stub audio after startEngine, as the device adapter would.
        try harness.files.prepare()
        try Data([0, 1, 2, 3]).write(to: harness.files.audioURL(for: captureID))

        // 2. Finals 1 and 2, then lock, then final 3.
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0, segment: segments[0])))
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0, segment: segments[1])))
        harness.coordinator.handle(.recorder(.protectedDataWillBecomeUnavailable))
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0, segment: segments[2])))

        // 3. Stop: final 4, transcriberEnded, engineStopped — all while locked.
        harness.coordinator.send(.tapStop)
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0, segment: segments[3])))
        harness.coordinator.handle(.recorder(.transcriberEnded(captureID: captureID, run: 0,
                                                               completed: true)))
        harness.coordinator.handle(.recorder(.engineStopped(captureID: captureID, duration: 30)))
        await harness.coordinator.drainEffects()

        // 4. Locked: the store is untouched; the journal holds everything.
        XCTAssertEqual(try fetchCaptures(in: harness.container).count, 0)
        let replay = try JournalReader.read(harness.files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.map(\.kind),
                       [.begin, .segment, .segment, .segment, .segment, .transcriberEnded, .end])
        XCTAssertEqual(replay.records.compactMap(\.text).filter { !$0.isEmpty },
                       ["one", "two", "three", "four"])

        // 5. Unlock: import happens; one .complete Capture with the 4 segments in order.
        harness.coordinator.handle(.recorder(.protectedDataDidBecomeAvailable))
        await harness.coordinator.drainEffects()
        let captures = try fetchCaptures(in: harness.container)
        XCTAssertEqual(captures.count, 1)
        let capture = try XCTUnwrap(captures.first)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, segments)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: harness.files.journalURL(for: captureID).path))
        // The JournalWriter's own protect call came first; the import's is last.
        XCTAssertEqual(harness.protector.calls.last?.url, harness.files.audioURL(for: captureID))
        XCTAssertEqual(harness.protector.calls.last?.type, .complete)
    }

    // MARK: - Store guard

    @MainActor
    func testNoStoreAccessWhileLocked() async throws {
        // Launch half: a complete journal on disk, but locked; run() must not touch the store.
        let lockedFiles = makeFiles()
        let lockedContainer = try RetoldSchema.makeInMemoryContainer()
        let lockedEngine = MockCaptureEngine()
        try lockedFiles.prepare()
        let journal: [JournalRecord] = [
            .begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                   createdAt: now, answering: nil, route: .speech(localeID: "en_US")),
            .end(captureID, duration: 5, reason: .userStop, endedAt: now),
        ]
        let writer = try JournalWriter(files: lockedFiles, captureID: captureID,
                                       protector: MockFileProtector())
        for record in journal { try writer.append(record) }
        writer.close()
        lockedEngine.finish()   // stream ends immediately

        let lockedCoordinator = CaptureCoordinator(
            engine: lockedEngine,
            fileTranscriber: MockFileTranscriber(),
            routeProvider: { .speech(localeID: "en_US") },
            files: lockedFiles,
            importer: JournalImporter(files: lockedFiles, durationProbe: MockDurationProbe(),
                                      protector: MockFileProtector()),
            container: lockedContainer,
            initialPermission: .granted,
            protectedDataAvailable: false,
            inbox: CaptureLaunchInbox(),
            makeWriter: { _, id in try JournalWriter(files: lockedFiles, captureID: id,
                                                     protector: MockFileProtector()) }
        )
        await lockedCoordinator.run()
        XCTAssertEqual(try fetchCaptures(in: lockedContainer).count, 0)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: lockedFiles.journalURL(for: captureID).path))

        // File-pass half: a .live Capture with audio, but locked; the transcriber is never called.
        let harness = try makeHarness(protectedDataAvailable: false)
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        try capture.updateTranscript([], status: .live)
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.transcriber.calls, 0)
    }

    @MainActor
    func testCrashOrphanImportedAndRetranscribedOnLaunch() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        // A journal by hand with no .end: the crash case.
        try harness.files.prepare()
        let records: [JournalRecord] = [
            .begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                   createdAt: now, answering: nil, route: .speech(localeID: "en_US")),
            .segment(captureID, run: 0,
                     segment: TranscriptSegment(text: "live partial", start: 0, end: 2, isFinal: true)),
        ]
        let writer = try JournalWriter(files: harness.files, captureID: captureID,
                                       protector: MockFileProtector())
        for record in records { try writer.append(record) }
        writer.close()
        try Data([0, 1]).write(to: harness.files.audioURL(for: captureID))

        let fileSegments = [
            TranscriptSegment(text: "from file one", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "from file two", start: 2, end: 4, isFinal: true),
        ]
        harness.transcriber.results = [.success(fileSegments)]
        harness.engine.finish()

        await harness.coordinator.run()
        await harness.coordinator.awaitFilePass()   // launch runs the pass in the background
        let captures = try fetchCaptures(in: harness.container)
        XCTAssertEqual(captures.count, 1)
        let capture = try XCTUnwrap(captures.first)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, fileSegments)
        XCTAssertEqual(harness.transcriber.calls, 1)
    }

    // MARK: - File pass

    @MainActor
    func testFilePassUsesRouteProvider() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        try capture.updateTranscript([], status: .live)
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.transcriber.routes, [.speech(localeID: "en_US")])
    }

    @MainActor
    func testFilePassLeavesLiveWhenRouteIsAudioOnly() async throws {
        let harness = try makeHarness()   // default route .audioOnly(.notChecked)
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        try capture.updateTranscript([], status: .live)
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.transcriber.calls, 0)
        let reloaded = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(reloaded.transcriptionStatus, .live)
    }

    @MainActor
    private func insertLiveCapture(_ harness: Harness,
                                   segments: [TranscriptSegment] = []) throws {
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        try capture.updateTranscript(segments, status: .live)
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()
    }

    @MainActor
    func testFilePassFailureMarksFailedAndKeepsPartial() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        let partial = [TranscriptSegment(text: "kept", start: 0, end: 1, isFinal: true)]
        try insertLiveCapture(harness, segments: partial)
        harness.transcriber.results = [.failure(JournalError.closed)]

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        let capture = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(capture.transcriptionStatus, .failed)
        XCTAssertEqual(capture.transcript, partial)
    }

    @MainActor
    func testFilePassEmptyResultDoesNotEraseLivePartial() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        let partial = [TranscriptSegment(text: "kept", start: 0, end: 1, isFinal: true)]
        try insertLiveCapture(harness, segments: partial)
        harness.transcriber.results = [.success([])]

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        let capture = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(capture.transcriptionStatus, .failed)
        XCTAssertEqual(capture.transcript, partial)
    }

    @MainActor
    func testFilePassSkipsCorrectedCapture() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        try capture.updateTranscript(
            [TranscriptSegment(text: "original", start: 0, end: 1, isFinal: true)], status: .live)
        try capture.addCorrection(segmentIndex: 0, correctedText: "corrected")
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.transcriber.calls, 0)
        let reloaded = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(reloaded.transcriptionStatus, .live)
        XCTAssertEqual(reloaded.corrections.count, 1)
    }

    @MainActor
    func testFilePassResumesFromFileStatus() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        try harness.files.prepare()
        try Data([0]).write(to: harness.files.audioURL(for: captureID))
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: captureID),
                              duration: 5, createdAt: now)
        capture.id = captureID
        // A previous pass was interrupted mid-flight: status .fromFile.
        try capture.updateTranscript([], status: .fromFile)
        let context = ModelContext(harness.container)
        context.insert(capture)
        try context.save()

        await harness.coordinator.retranscribePending()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.transcriber.calls, 1)
        let reloaded = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(reloaded.transcriptionStatus, .complete)
    }

    @MainActor
    func testFilePassIsSingleFlight() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        try insertLiveCapture(harness)
        harness.transcriber.gateEnabled = true
        let segments = [TranscriptSegment(text: "done", start: 0, end: 1, isFinal: true)]
        harness.transcriber.results = [.success(segments)]

        let coordinator = harness.coordinator
        let first = Task { await coordinator.retranscribePending() }
        // Wait until the pass is inside the gated transcriber.
        for _ in 0..<1_000 where harness.transcriber.gateWaiterCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(harness.transcriber.gateWaiterCount, 1)
        let second = Task { await coordinator.retranscribePending() }
        await Task.yield()

        harness.transcriber.releaseGate()
        await first.value
        await second.value
        await harness.coordinator.drainEffects()

        // The rerun found no .live captures: the transcriber ran once, never twice.
        XCTAssertEqual(harness.transcriber.calls, 1)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, segments)
    }

    @MainActor
    func testLockDuringFilePassDoesNotSave() async throws {
        let harness = try makeHarness(route: .speech(localeID: "en_US"))
        try insertLiveCapture(harness)
        let before = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        let beforeStatus = before.transcriptionStatus
        let beforeTranscript = before.transcript
        harness.transcriber.gateEnabled = true
        harness.transcriber.results = [.success([
            TranscriptSegment(text: "late", start: 0, end: 1, isFinal: true)])]

        let coordinator = harness.coordinator
        let pass = Task { await coordinator.retranscribePending() }
        for _ in 0..<1_000 where harness.transcriber.gateWaiterCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(harness.transcriber.gateWaiterCount, 1)
        // The phone locks while the file is being transcribed.
        harness.coordinator.handle(.recorder(.protectedDataWillBecomeUnavailable))
        harness.transcriber.releaseGate()
        await pass.value

        let after = try XCTUnwrap(fetchCapture(captureID, in: harness.container))
        XCTAssertEqual(after.transcriptionStatus, beforeStatus)
        XCTAssertEqual(after.transcript, beforeTranscript)
    }

    // MARK: - Journal failures

    @MainActor
    func testJournalOpenFailureStopsCleanly() async throws {
        let harness = try makeHarness(makeWriter: { _, _ in
            throw JournalError.alreadyExists
        })
        harness.coordinator.send(.startRequested(answering: nil))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        XCTAssertNotNil(harness.coordinator.journalError)
        // The engine gets stop; after engineStopped the state is .idle with no second error.
        await harness.coordinator.drainEffects()
        XCTAssertTrue(harness.engine.recordedCalls.contains(.stop(captureID: captureID)))
        harness.coordinator.handle(.recorder(.engineStopped(captureID: captureID, duration: 0)))
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.coordinator.state.phase, .idle)
    }

    @MainActor
    func testAppendFailureForcesFilePass() async throws {
        let mockWriter = MockJournalWriter(captureID: captureID)
        mockWriter.failOnAppends = [2]          // the first segment is lost
        let harness = try makeHarness(makeWriter: { _, _ in mockWriter })
        harness.coordinator.send(.startRequested(answering: nil))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0,
            segment: TranscriptSegment(text: "lost", start: 0, end: 1, isFinal: true))))
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0,
            segment: TranscriptSegment(text: "kept", start: 1, end: 2, isFinal: true))))
        harness.coordinator.handle(.recorder(.transcriberEnded(captureID: captureID, run: 0,
                                                               completed: true)))

        let texts = mockWriter.records.compactMap(\.text)
        XCTAssertEqual(texts, ["kept"])        // later appends still land
        let ended = try XCTUnwrap(mockWriter.records.last { $0.kind == .transcriberEnded })
        XCTAssertEqual(ended.completed, false)  // so the importer queues the file pass
    }

    @MainActor
    func testAppendFailureKeepsRecording() async throws {
        let mockWriter = MockJournalWriter(captureID: captureID)
        mockWriter.failOnAppends = [3]
        let harness = try makeHarness(makeWriter: { _, id in
            XCTAssertEqual(id, self.captureID)
            return mockWriter
        })
        harness.coordinator.send(.startRequested(answering: nil))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))

        // Appends 1 (begin) and 2 succeed; 3 throws.
        for index in 0..<3 {
            harness.coordinator.handle(.recorder(.finalSegment(
                captureID: captureID, run: 0,
                segment: TranscriptSegment(text: "s\(index)", start: 0, end: 1, isFinal: true))))
        }
        XCTAssertEqual(harness.coordinator.state.phase, .recording(captureID: captureID))
        XCTAssertNotNil(harness.coordinator.journalError)
    }

    @MainActor
    func testVolatileTextIsNeverJournaled() async throws {
        // Locked, so no import runs and the journal file stays on disk to inspect.
        let harness = try makeHarness(protectedDataAvailable: false)
        try harness.files.prepare()
        harness.coordinator.send(.startRequested(answering: nil))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        harness.coordinator.handle(.recorder(.finalSegment(
            captureID: captureID, run: 0,
            segment: TranscriptSegment(text: "journaled", start: 0, end: 1, isFinal: true))))
        harness.coordinator.handle(.volatile(captureID: captureID, text: "xyz"))
        XCTAssertEqual(harness.coordinator.liveText, "journaled xyz")
        harness.coordinator.send(.tapStop)
        harness.coordinator.handle(.recorder(.engineStopped(captureID: captureID, duration: 1)))
        await harness.coordinator.drainEffects()

        let raw = try String(contentsOf: harness.files.journalURL(for: captureID),
                             encoding: .utf8)
        XCTAssertTrue(raw.contains("journaled"))
        XCTAssertFalse(raw.contains("xyz"))
    }

    // MARK: - Effect ordering

    @MainActor
    func testEngineCallsKeepEffectOrder() async throws {
        let harness = try makeHarness(newID: { [captureID] in captureID })
        harness.coordinator.send(.startRequested(answering: nil))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        harness.coordinator.send(.interruptionBegan)
        harness.coordinator.send(.tapResume)
        harness.coordinator.send(.tapStop)
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.engine.recordedCalls, [
            .start(captureID: captureID, route: .audioOnly(.notChecked)),
            .pause(captureID: captureID),
            .resume(captureID: captureID),
            .stop(captureID: captureID),
        ])
    }

    // MARK: - Launch inbox

    @MainActor
    func testLaunchInboxStartsCaptureAfterPermissionRefresh() async throws {
        let harness = try makeHarness(initialPermission: .undetermined,
                                      newID: { [captureID] in captureID })
        harness.engine.permission = .granted

        harness.inbox.request()
        await harness.coordinator.drainLaunchInbox()
        await harness.coordinator.drainEffects()
        XCTAssertTrue(harness.engine.recordedCalls.contains(
            .start(captureID: captureID, route: .audioOnly(.notChecked))))

        // A second drain with nothing pending does nothing new.
        let callsAfterFirstDrain = harness.engine.recordedCalls
        await harness.coordinator.drainLaunchInbox()
        await harness.coordinator.drainEffects()
        XCTAssertEqual(harness.engine.recordedCalls, callsAfterFirstDrain)
    }

    @MainActor
    func testInboxRequestHookDrains() async throws {
        let harness = try makeHarness()
        harness.inbox.request()     // alone: proves the onRequest path
        for _ in 0..<1_000 where !harness.engine.recordedCalls.contains(
            where: { if case .start = $0 { true } else { false } }) {
            await Task.yield()
        }
        XCTAssertTrue(harness.engine.recordedCalls.contains(where: {
            if case .start = $0 { return true } else { return false }
        }))
    }

    @MainActor
    func testAnsweringFlowsToCapture() async throws {
        let questionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E2")!
        let harness = try makeHarness(newID: { [captureID] in captureID })
        harness.coordinator.send(.startRequested(answering: questionID))
        await harness.coordinator.drainEffects()
        harness.coordinator.handle(.recorder(.engineStarted(captureID: captureID)))
        harness.coordinator.send(.tapStop)
        harness.coordinator.handle(.recorder(.engineStopped(captureID: captureID, duration: 1)))
        await harness.coordinator.drainEffects()

        let capture = try XCTUnwrap(try fetchCaptures(in: harness.container).first)
        XCTAssertEqual(capture.answersQuestionID, questionID)
    }

    @MainActor
    func testEventsStreamPathIsHandled() async throws {
        let harness = try makeHarness()
        let eventCount = 5
        for _ in 0..<eventCount {
            harness.engine.push(.sceneDidBecomeActive)
        }
        harness.engine.finish()
        await harness.coordinator.run()
        XCTAssertEqual(harness.coordinator.processedEventCount, eventCount)
    }
}
