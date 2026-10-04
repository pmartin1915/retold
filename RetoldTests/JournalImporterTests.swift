import Foundation
import SwiftData
import XCTest
@testable import Retold

/// Journal import, orphan adoption and the §4.3 status table
/// (docs/R6-RECORDER-SPEC.md §5.1 and §6).
final class JournalImporterTests: XCTestCase {
    private let captureID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
    private let questionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    // No setUp/tearDown overrides: each test makes its own files/container and registers
    // teardown blocks (a non-isolated class cannot override them for @MainActor tests).

    private func makeFiles() -> CaptureFiles {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-importer-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return CaptureFiles(root: root)
    }

    private func makeContainer() throws -> ModelContainer {
        try RetoldSchema.makeInMemoryContainer()
    }

    @MainActor
    private func makeImporter(_ files: CaptureFiles, probe: MockDurationProbe? = nil,
                              protector: MockFileProtector? = nil)
        -> (JournalImporter, MockDurationProbe, MockFileProtector) {
        let probe = probe ?? MockDurationProbe()
        let protector = protector ?? MockFileProtector()
        return (JournalImporter(files: files, durationProbe: probe, protector: protector), probe, protector)
    }

    /// Writes `records` to the capture's journal with a real JournalWriter.
    private func writeJournal(_ files: CaptureFiles, _ records: [JournalRecord]) throws {
        try files.prepare()
        let writer = try JournalWriter(files: files, captureID: captureID,
                                       protector: MockFileProtector())
        for record in records {
            try writer.append(record)
        }
        writer.close()
    }

    private func stubAudio(_ files: CaptureFiles, id: UUID = UUID()) throws -> URL {
        try files.prepare()
        let url = files.audioURL(for: id)
        try Data([0, 1, 2, 3]).write(to: url)
        return url
    }

    private func fetchCapture(_ id: UUID, in container: ModelContainer) throws -> Capture? {
        let cid = id
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        return try context.fetch(descriptor).first
    }

    private func captureCount(in container: ModelContainer) throws -> Int {
        try ModelContext(container).fetch(FetchDescriptor<Capture>()).count
    }

    private func sampleSegments() -> [TranscriptSegment] {
        [
            TranscriptSegment(text: "first words", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "second breath", start: 2, end: 4, isFinal: true),
        ]
    }

    /// A complete journal: begin, runStarted, segments, transcriberEnded(true), end.
    private func completeJournal(route: TranscriptionRoute = .speech(localeID: "en_US"),
                                 duration: TimeInterval = 30,
                                 completed: Bool = true) -> [JournalRecord] {
        var records: [JournalRecord] = [
            .begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                   createdAt: date, answering: questionID, route: route),
            .runStarted(captureID, run: 0, audioOffset: 0),
        ]
        records += sampleSegments().map { .segment(captureID, run: 0, segment: $0) }
        records.append(.transcriberEnded(captureID, run: 0, completed: completed))
        records.append(.end(captureID, duration: duration, reason: .userStop, endedAt: date))
        return records
    }

    // MARK: - Status table (§4.3)

    @MainActor
    func testCompletedJournalImportsCompleteCapture() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.imported, [captureID])

        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.id, captureID)
        XCTAssertEqual(capture.audioFileName, CaptureFiles.audioFileName(for: captureID))
        XCTAssertEqual(capture.duration, 30)
        XCTAssertEqual(capture.createdAt, date)
        XCTAssertEqual(capture.answersQuestionID, questionID)
        XCTAssertEqual(capture.transcript, sampleSegments())
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertNotNil(capture.completedTranscript)
    }

    @MainActor
    func testLastTranscriberEndedDecides() throws {
        // completed true, then a later false -> .live.
        var records = completeJournal()
        records.append(.transcriberEnded(captureID, run: 1, completed: false))
        // The extra record must not be an .end or it would still be "ended"; make the last
        // transcriberEnded's run later than the .end is not possible in a real journal, but the
        // rule reads the LAST transcriberEnded record, so exercise exactly that.
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, records)
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.imported, [captureID])
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, sampleSegments())
    }

    @MainActor
    func testJournalWithoutTranscriberEndImportsLive() throws {
        var records = completeJournal()
        records.removeAll { $0.kind == .transcriberEnded }
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, records)
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, sampleSegments())
    }

    @MainActor
    func testAudioOnlyRouteImportsLiveForFilePass() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal(route: .audioOnly(.assetsNotInstalled)))
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, [])   // the file pass uses the current route
    }

    @MainActor
    func testUnparseableRouteImportsLive() throws {
        let records = completeJournal().map { record -> JournalRecord in
            var r = record
            if r.kind == .begin { r.route = "fax:en_US" }
            return r
        }
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, records)
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, sampleSegments())
    }

    @MainActor
    func testCrashOrphanUsesProbedDuration() throws {
        // No .end: the duration comes from the probe.
        var records = completeJournal()
        records.removeAll { $0.kind == .end }
        let files = makeFiles()
        let audioURL = try stubAudio(files, id: captureID)
        try writeJournal(files, records)
        let container = try makeContainer()
        let (importer, probe, _) = makeImporter(files)
        probe.setDuration(42.0, for: audioURL)

        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.duration, 42.0)
        XCTAssertEqual(capture.transcriptionStatus, .live)
    }

    @MainActor
    func testCrashOrphanWithUnreadableAudioHasZeroDuration() throws {
        var records = completeJournal()
        records.removeAll { $0.kind == .end }
        let files = makeFiles()
        try writeJournal(files, records)             // no audio file at all
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.duration, 0)
        XCTAssertEqual(capture.transcriptionStatus, .live)
    }

    // MARK: - Protect, remove, retry

    @MainActor
    func testImportDeletesJournalAndProtectsAudio() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, protector) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(protector.calls.count, 1)
        XCTAssertEqual(protector.calls[0].url, files.audioURL(for: captureID))
        XCTAssertEqual(protector.calls[0].type, .complete)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: files.journalURL(for: captureID).path))
    }

    @MainActor
    func testProtectFailureKeepsJournalAndRetries() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, protector) = makeImporter(files)
        protector.failNext([JournalError.closed])

        let first = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(first.protectFailed, [captureID])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: files.journalURL(for: captureID).path))   // journal kept

        // Second import: the row exists, protection is retried, the journal is then removed.
        let second = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(second.alreadyPresent, [captureID])
        XCTAssertEqual(protector.calls.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: files.journalURL(for: captureID).path))
        XCTAssertEqual(try captureCount(in: container), 1)
    }

    @MainActor
    func testImportIsIdempotent() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let first = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(first.imported, [captureID])
        let second = importer.importAll(into: container, excluding: nil)
        XCTAssertTrue(second.imported.isEmpty)
        XCTAssertEqual(second.alreadyPresent, [captureID])
        XCTAssertEqual(try captureCount(in: container), 1)
    }

    @MainActor
    func testCrashAfterSaveBeforeDeleteDoesNotDuplicate() throws {
        // Simulate the crash: import once, then put the journal BACK on disk and import again.
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        try writeJournal(files, completeJournal())
        let again = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(again.alreadyPresent, [captureID])
        XCTAssertEqual(try captureCount(in: container), 1)
    }

    @MainActor
    func testExcludedCaptureIsNotImported() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: captureID)
        XCTAssertTrue(report.imported.isEmpty)
        XCTAssertEqual(try captureCount(in: container), 0)
        // Neither the journal nor the audio is adopted or removed.
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: files.journalURL(for: captureID).path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: files.audioURL(for: captureID).path))
    }

    // MARK: - Quarantine and salvage

    @MainActor
    func testMissingBeginIsQuarantinedAndAudioAdopted() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try files.prepare()
        // A journal whose first line is a segment: .missingBegin.
        let bad = JournalRecord.segment(
            captureID, run: 0, segment: TranscriptSegment(text: "x", start: 0, end: 1, isFinal: true))
        try JournalCoding.line(bad).write(to: files.journalURL(for: captureID))
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.quarantined.count, 1)
        XCTAssertEqual(report.quarantined[0].lastPathComponent,
                       "\(captureID.uuidString).jsonl.bad")
        // The audio is adopted anyway.
        XCTAssertEqual(report.adoptedOrphans, [captureID])
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, [])
        XCTAssertEqual(try captureCount(in: container), 1)
    }

    @MainActor
    func testCorruptJournalSalvagesThenQuarantines() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try files.prepare()
        let records = completeJournal()
        var text = ""
        for (index, record) in records.enumerated() {
            if index == 3 {
                text += "not json at all\n"     // corrupt physical line 4 of 7
            } else {
                text += String(decoding: try JournalCoding.line(record), as: UTF8.self)
            }
        }
        try Data(text.utf8).write(to: files.journalURL(for: captureID))
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.imported, [captureID])
        XCTAssertEqual(report.quarantined.count, 1)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcript, Array(sampleSegments().prefix(1)))
        XCTAssertEqual(capture.transcriptionStatus, .live)
    }

    // MARK: - Orphans

    @MainActor
    func testOrphanAudioWithoutJournalIsAdopted() throws {
        let files = makeFiles()
        let audioURL = try stubAudio(files, id: captureID)
        let container = try makeContainer()
        let (importer, probe, protector) = makeImporter(files)
        probe.setDuration(9.5, for: audioURL)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.adoptedOrphans, [captureID])
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.audioFileName, CaptureFiles.audioFileName(for: captureID))
        XCTAssertEqual(capture.duration, 9.5)
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, [])
        XCTAssertEqual(protector.calls.count, 1)
        XCTAssertEqual(protector.calls[0].type, .complete)
    }

    @MainActor
    func testTornTailStillImportsEarlierSegments() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try files.prepare()
        let good = completeJournal().map {
            String(decoding: try JournalCoding.line($0), as: UTF8.self)
        }.joined()
        try Data((good + #"{"captureID":"00000000-0000-00"#).utf8)
            .write(to: files.journalURL(for: captureID))
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertEqual(report.imported, [captureID])
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcript, sampleSegments())
        XCTAssertEqual(capture.transcriptionStatus, .complete)
    }

    @MainActor
    func testVerbatimTextSurvivesEndToEnd() throws {
        // Segment texts that exercise whitespace, case, emoji, combining marks and line
        // separators. Reducer -> JournalWriter -> JournalReader -> importer, compared verbatim.
        let expected: [TranscriptSegment] = [
            TranscriptSegment(text: "  leading spaces", start: 0, end: 1, isFinal: true),
            TranscriptSegment(text: "TRAILING spaces  ", start: 1, end: 2, isFinal: true),
            TranscriptSegment(text: "Mixed CASE Text", start: 2, end: 3, isFinal: true),
            TranscriptSegment(text: "emoji 🙂 done", start: 3, end: 4, isFinal: true),
            TranscriptSegment(text: "combining e\u{301} mark", start: 4, end: 5, isFinal: true),
            TranscriptSegment(text: "line separator \u{2028} here", start: 5, end: 6, isFinal: true),
            TranscriptSegment(text: "a\nb", start: 6, end: 7, isFinal: true),
        ]
        let files = makeFiles()
        try stubAudio(files, id: captureID)

        // Reducer: recording state, run 0 at offset 0.
        var state = RecorderState(permission: .granted, protectedDataAvailable: true)
        var records: [JournalRecord] = []
        (state, _) = RecorderMachine.reduce(state, .startRequested(answering: nil),
                                            now: date) { self.captureID }
        (state, _) = RecorderMachine.reduce(state, .engineStarted(captureID: captureID),
                                            now: date) { self.captureID }
        (state, _) = RecorderMachine.reduce(
            state, .transcriberRunStarted(captureID: captureID, run: 0, audioOffset: 0),
            now: date) { self.captureID }
        for segment in expected {
            let (_, effects) = RecorderMachine.reduce(
                state, .finalSegment(captureID: captureID, run: 0, segment: segment),
                now: date) { self.captureID }
            records += effects.compactMap { if case .journal(let r) = $0 { r } else { nil } }
        }
        (state, _) = RecorderMachine.reduce(
            state, .transcriberEnded(captureID: captureID, run: 0, completed: true),
            now: date) { self.captureID }
        let (_, endEffects) = RecorderMachine.reduce(
            state, .engineStopped(captureID: captureID, duration: 7), now: date) { self.captureID }
        records += endEffects.compactMap { if case .journal(let r) = $0 { r } else { nil } }

        // JournalWriter -> JournalReader.
        let writer = try JournalWriter(files: files, captureID: captureID,
                                       protector: MockFileProtector())
        for record in records {
            try writer.append(record)
        }
        writer.close()
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, records.count)

        // Importer -> Capture.
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)
        _ = importer.importAll(into: container, excluding: nil)
        let capture = try XCTUnwrap(fetchCapture(captureID, in: container))
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, expected)
    }

    @MainActor
    func testImporterCreatesNoOtherEntities() throws {
        let files = makeFiles()
        try stubAudio(files, id: captureID)
        try writeJournal(files, completeJournal())
        let container = try makeContainer()
        let (importer, _, _) = makeImporter(files)

        _ = importer.importAll(into: container, excluding: nil)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Episode>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Question>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Detail>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Person>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Place>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Period>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Capture>()).count, 1)
    }
}

