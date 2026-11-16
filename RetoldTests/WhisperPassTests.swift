import Foundation
import SwiftData
import XCTest
@testable import Retold

/// A scripted after-Stop pass. Locked state; @unchecked Sendable in tests only.
final class MockAfterStopPass: AfterStopPass, @unchecked Sendable {
    private let lock = NSLock()
    private var _ready = true
    private var _memoryMB: Int?
    private var _result: Result<[TranscriptSegment], Error> = .success([])
    private var _hold = false
    private var _calls = 0

    var ready: Bool {
        get { lock.withLock { _ready } }
        set { lock.withLock { _ready = newValue } }
    }
    var memoryMB: Int? {
        get { lock.withLock { _memoryMB } }
        set { lock.withLock { _memoryMB = newValue } }
    }
    var result: Result<[TranscriptSegment], Error> {
        get { lock.withLock { _result } }
        set { lock.withLock { _result = newValue } }
    }
    /// When true, transcribe sleeps until cancelled (a pass that never finishes on its own).
    var hold: Bool {
        get { lock.withLock { _hold } }
        set { lock.withLock { _hold = newValue } }
    }
    var calls: Int { lock.withLock { _calls } }

    func isReady() -> Bool { ready }
    func availableMemoryMB() -> Int? { memoryMB }

    func transcribe(audioURL: URL) async throws -> [TranscriptSegment] {
        lock.withLock { _calls += 1 }
        if hold {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
            }
            throw CancellationError()
        }
        return try result.get()
    }
}

/// The Whisper pass after Stop (docs/WHISPER-PASS-SPEC.md sections 2-3): the importer's mark and the
/// coordinator's outcome table, driven by mocks. The real model runs in RetoldListenHarness.
final class WhisperPassTests: XCTestCase {
    private let captureID = UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private enum Failure: Error { case scripted }

    private let apple = [
        TranscriptSegment(text: "my grandmother Ada lived on Elm street", start: 0, end: 3, isFinal: true),
        TranscriptSegment(text: "she baked bread", start: 3, end: 5, isFinal: true),
    ]
    private let whisper = [
        TranscriptSegment(text: "My grandmother Adah lived on Elm Street.", start: 0, end: 3, isFinal: true),
        TranscriptSegment(text: "She baked bread.", start: 3, end: 5, isFinal: true),
    ]

    private struct Setup {
        let coordinator: CaptureCoordinator
        let engine: MockCaptureEngine
        let fileTranscriber: MockFileTranscriber
        let pass: MockAfterStopPass
        let ledger: WhisperPassLedger
        let files: CaptureFiles
        let container: ModelContainer
    }

    private func makeLedger() -> WhisperPassLedger {
        let suite = "retold-whisper-tests-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return WhisperPassLedger(defaults: UserDefaults(suiteName: suite)!)
    }

    @MainActor
    private func makeSetup(withPass: Bool = true,
                           whisperTimeLimit: @escaping @Sendable (TimeInterval) -> TimeInterval = { _ in 30 })
        throws -> Setup {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-whisper-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let files = CaptureFiles(root: root)
        try files.prepare()
        let container = try RetoldSchema.makeInMemoryContainer()
        let engine = MockCaptureEngine()
        let fileTranscriber = MockFileTranscriber()
        let pass = MockAfterStopPass()
        let ledger = makeLedger()
        let protector = MockFileProtector()
        let importer = JournalImporter(files: files, durationProbe: MockDurationProbe(), protector: protector,
                                       afterStopPass: withPass ? pass : nil, ledger: withPass ? ledger : nil)
        // A new recording gets its own ID, never the marked capture's.
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000F2")!
        let coordinator = CaptureCoordinator(
            engine: engine,
            fileTranscriber: fileTranscriber,
            routeProvider: { .speech(localeID: "en_US") },
            files: files,
            importer: importer,
            container: container,
            initialPermission: .granted,
            protectedDataAvailable: true,
            inbox: CaptureLaunchInbox(),
            makeWriter: { files, captureID in
                try JournalWriter(files: files, captureID: captureID, protector: protector)
            },
            newID: { id },
            whisperTimeLimit: whisperTimeLimit)
        return Setup(coordinator: coordinator, engine: engine, fileTranscriber: fileTranscriber, pass: pass,
                     ledger: ledger, files: files, container: container)
    }

    /// A journal for a live run that completed (begin, run, Apple's segments, ended, end) + audio.
    private func writeCompletedJournal(_ setup: Setup, route: TranscriptionRoute = .speech(localeID: "en_US"),
                                       completed: Bool = true) throws {
        let writer = try JournalWriter(files: setup.files, captureID: captureID, protector: MockFileProtector())
        var records: [JournalRecord] = [
            .begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                   createdAt: date, answering: nil, route: route),
            .runStarted(captureID, run: 0, audioOffset: 0),
        ]
        records += apple.map { .segment(captureID, run: 0, segment: $0) }
        records.append(.transcriberEnded(captureID, run: 0, completed: completed))
        records.append(.end(captureID, duration: 5, reason: .userStop, endedAt: date))
        for record in records { try writer.append(record) }
        writer.close()
        try Data([0, 1, 2, 3]).write(to: setup.files.audioURL(for: captureID))
    }

    @MainActor
    private func importOnly(_ setup: Setup) {
        _ = setup.coordinator.importer.importAll(into: setup.container, excluding: nil)
    }

    private func fetch(_ setup: Setup) throws -> Capture {
        let cid = captureID
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        return try XCTUnwrap(ModelContext(setup.container).fetch(descriptor).first)
    }

    private func texts(_ capture: Capture) -> [String] { capture.transcript.map(\.text) }

    // MARK: - Importer (section 2)

    @MainActor
    func testImporterMarksWhenModelReady() async throws {
        let setup = try makeSetup()
        try writeCompletedJournal(setup)
        importOnly(setup)
        let capture = try fetch(setup)
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(texts(capture), apple.map(\.text))     // Apple's words kept while waiting
        XCTAssertTrue(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testImporterCompletesAsTodayWhenModelAbsent() async throws {
        let setup = try makeSetup()
        setup.pass.ready = false
        try writeCompletedJournal(setup)
        importOnly(setup)
        XCTAssertEqual(try fetch(setup).transcriptionStatus, .complete)
        XCTAssertFalse(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testImporterCompletesAsTodayWithoutPass() async throws {
        let setup = try makeSetup(withPass: false)
        try writeCompletedJournal(setup)
        importOnly(setup)
        XCTAssertEqual(try fetch(setup).transcriptionStatus, .complete)
    }

    @MainActor
    func testImporterCompletesNonEnglishAsToday() async throws {
        let setup = try makeSetup()
        try writeCompletedJournal(setup, route: .speech(localeID: "fr_FR"))
        importOnly(setup)
        XCTAssertEqual(try fetch(setup).transcriptionStatus, .complete)
        XCTAssertFalse(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testFailedLiveRunIsNotMarkedAndGetsAppleFilePass() async throws {
        let setup = try makeSetup()
        setup.fileTranscriber.results = [.success(whisper)]
        try writeCompletedJournal(setup, completed: false)
        importOnly(setup)
        XCTAssertFalse(setup.ledger.isMarked(captureID))
        await setup.coordinator.retranscribePending()
        XCTAssertEqual(setup.fileTranscriber.calls, 1)
        XCTAssertEqual(setup.pass.calls, 0)
        XCTAssertEqual(try fetch(setup).transcriptionStatus, .complete)
    }

    // MARK: - Outcomes (section 3)

    @MainActor
    private func markedAndPassed(_ setup: Setup) async throws -> Capture {
        try writeCompletedJournal(setup)
        importOnly(setup)
        await setup.coordinator.retranscribePending()
        return try fetch(setup)
    }

    @MainActor
    func testWhisperWordsAreKept() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success(whisper)
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), whisper.map(\.text))
        XCTAssertFalse(setup.ledger.isMarked(captureID))
        XCTAssertEqual(setup.fileTranscriber.calls, 0)        // never the Apple file pass too
    }

    @MainActor
    func testWhisperErrorKeepsApple() async throws {
        let setup = try makeSetup()
        setup.pass.result = .failure(Failure.scripted)
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(capture.transcriptionStatus, .complete)   // never .failed
        XCTAssertEqual(texts(capture), apple.map(\.text))
        XCTAssertFalse(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testEmptyWhisperKeepsApple() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success([])
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))
    }

    @MainActor
    func testShortWhisperKeepsApple() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success([TranscriptSegment(text: "Thank you.", start: 0, end: 1, isFinal: true)])
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(texts(capture), apple.map(\.text))
    }

    @MainActor
    func testLowMemoryKeepsAppleWithoutLoading() async throws {
        let setup = try makeSetup()
        setup.pass.memoryMB = 600
        setup.pass.result = .success(whisper)
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(setup.pass.calls, 0)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))
    }

    @MainActor
    func testModelDeletedKeepsApple() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success(whisper)
        try writeCompletedJournal(setup)
        importOnly(setup)
        setup.pass.ready = false                                // deleted in Settings meanwhile
        await setup.coordinator.retranscribePending()
        let capture = try fetch(setup)
        XCTAssertEqual(setup.pass.calls, 0)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))
    }

    @MainActor
    func testCorrectionsKeepApple() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success(whisper)
        try writeCompletedJournal(setup)
        importOnly(setup)
        let context = ModelContext(setup.container)
        let cid = captureID
        let row = try XCTUnwrap(context.fetch(FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })).first)
        try row.addCorrection(segmentIndex: 0, correctedText: "my grandmother Adah")
        try context.save()

        await setup.coordinator.retranscribePending()
        let capture = try fetch(setup)
        XCTAssertEqual(setup.pass.calls, 0)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))       // correction indices stay valid
        XCTAssertEqual(capture.corrections.count, 1)
    }

    @MainActor
    func testTimeoutKeepsApple() async throws {
        let setup = try makeSetup(whisperTimeLimit: { _ in 0.2 })
        setup.pass.hold = true
        let capture = try await markedAndPassed(setup)
        XCTAssertEqual(setup.pass.calls, 1)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))
        XCTAssertFalse(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testAttemptCapKeepsAppleWithoutLoading() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success(whisper)
        try writeCompletedJournal(setup)
        importOnly(setup)
        // Two earlier passes the process did not survive (jetsam): no fallback code ran.
        setup.ledger.beginAttempt(captureID)
        setup.ledger.beginAttempt(captureID)
        await setup.coordinator.retranscribePending()
        let capture = try fetch(setup)
        XCTAssertEqual(setup.pass.calls, 0)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(texts(capture), apple.map(\.text))
        XCTAssertFalse(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testAttemptIsCountedBeforeTheModelLoads() async throws {
        let setup = try makeSetup(whisperTimeLimit: { _ in 0.3 })
        setup.pass.hold = true
        try writeCompletedJournal(setup)
        importOnly(setup)
        let passTask = Task { await setup.coordinator.retranscribePending() }
        while setup.pass.calls == 0 { await Task.yield() }
        XCTAssertEqual(setup.ledger.attempts(captureID), 1)    // a kill now still counts
        await passTask.value
    }

    @MainActor
    func testNoWhisperWhileRecordingAndCaptureStaysMarked() async throws {
        let setup = try makeSetup()
        setup.pass.result = .success(whisper)
        try writeCompletedJournal(setup)
        importOnly(setup)
        // Another capture is recording when the pass comes round.
        let coordinator = setup.coordinator
        coordinator.send(.startRequested(answering: nil))
        await coordinator.drainEffects()
        XCTAssertNotNil(coordinator.activeCaptureID)
        await coordinator.retranscribePending()
        XCTAssertEqual(setup.pass.calls, 0)
        let capture = try fetch(setup)
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertTrue(setup.ledger.isMarked(captureID))
    }

    @MainActor
    func testRecordingStartCancelsRunningPassAndCaptureStaysMarked() async throws {
        let setup = try makeSetup()
        setup.pass.hold = true                                   // ends only when cancelled
        try writeCompletedJournal(setup)
        importOnly(setup)
        let passTask = Task { await setup.coordinator.retranscribePending() }
        while setup.pass.calls == 0 { await Task.yield() }
        setup.coordinator.send(.startRequested(answering: nil))
        await setup.coordinator.drainEffects()
        await passTask.value
        let capture = try fetch(setup)
        XCTAssertEqual(capture.transcriptionStatus, .live)       // waits for a later pass
        XCTAssertTrue(setup.ledger.isMarked(captureID))
        XCTAssertEqual(setup.ledger.attempts(captureID), 0)      // not a failure
    }

    @MainActor
    func testRetranscribeFinishesStaleMarkerAndPrunesGoneCaptures() async throws {
        let setup = try makeSetup()
        let gone = UUID()
        setup.ledger.mark(gone)                                  // its capture was deleted
        await setup.coordinator.retranscribePending()
        XCTAssertFalse(setup.ledger.isMarked(gone))
    }

    // MARK: - Limits

    func testAcceptsNeedsWordsAndHalfOfApple() {
        XCTAssertTrue(WhisperPassLimits.accepts(whisper: whisper, apple: apple))
        XCTAssertFalse(WhisperPassLimits.accepts(whisper: [], apple: apple))
        XCTAssertTrue(WhisperPassLimits.accepts(whisper: whisper, apple: []))
        XCTAssertFalse(WhisperPassLimits.accepts(
            whisper: [TranscriptSegment(text: "Thank you.", start: 0, end: 1, isFinal: true)], apple: apple))
    }

    func testTimeLimitScalesWithDuration() {
        XCTAssertEqual(WhisperPassLimits.timeLimit(duration: 0), 60)
        XCTAssertEqual(WhisperPassLimits.timeLimit(duration: 30 * 60), 60 + 15 * 30)
    }

    func testEnglishOnly() {
        XCTAssertTrue(WhisperPassLimits.isEnglish(localeID: "en_US"))
        XCTAssertTrue(WhisperPassLimits.isEnglish(localeID: "en-GB"))
        XCTAssertFalse(WhisperPassLimits.isEnglish(localeID: "fr_FR"))
    }

    func testLedgerGiveBackNeverGoesBelowZero() {
        let ledger = makeLedger()
        let id = UUID()
        ledger.mark(id)
        ledger.beginAttempt(id)
        ledger.giveBack(id)
        ledger.giveBack(id)
        XCTAssertEqual(ledger.attempts(id), 0)
        XCTAssertTrue(ledger.isMarked(id))
        ledger.remove(id)
        XCTAssertFalse(ledger.isMarked(id))
    }
}
