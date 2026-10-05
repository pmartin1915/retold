import Foundation
import SwiftData
import XCTest
@testable import Retold

/// Deleting an unfiled capture (docs/R7C-SPEC.md section 6).
@MainActor
final class CaptureDeleterTests: XCTestCase {
    private struct RemovalFailure: Error {}

    private func makeFiles() throws -> CaptureFiles {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-deleter-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let files = CaptureFiles(root: root)
        try files.prepare()
        return files
    }

    /// An unfiled capture in the store, saved so the deleter's fresh context sees it.
    private func insertCapture(in container: ModelContainer, id: UUID = UUID()) throws -> Capture {
        let capture = Capture(audioFileName: CaptureFiles.audioFileName(for: id), duration: 5,
                              createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        capture.id = id
        container.mainContext.insert(capture)
        try container.mainContext.save()
        return capture
    }

    private struct Stubs {
        let audio: URL
        let journal: URL
        let bad: URL
    }

    /// Writes the audio file, the journal and the quarantined journal for `id`.
    private func stubFiles(_ files: CaptureFiles, id: UUID) throws -> Stubs {
        let audio = files.audioURL(for: id)
        let journal = files.journalURL(for: id)
        let bad = journal.appendingPathExtension("bad")
        for url in [audio, journal, bad] {
            try Data([0, 1, 2, 3]).write(to: url)
        }
        return Stubs(audio: audio, journal: journal, bad: bad)
    }

    private func fetchCapture(_ id: UUID, in container: ModelContainer) throws -> Capture? {
        let cid = id
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        return try context.fetch(descriptor).first
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func testDeleteRemovesRecordAudioAndJournals() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        let stubs = try stubFiles(files, id: id)

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)

        XCTAssertNil(try fetchCapture(id, in: container))
        XCTAssertFalse(exists(stubs.audio))
        XCTAssertFalse(exists(stubs.journal))
        XCTAssertFalse(exists(stubs.bad))
    }

    func testDeletedCaptureIsNotResurrectedByImport() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        _ = try stubFiles(files, id: id)

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)

        let importer = JournalImporter(files: files, durationProbe: MockDurationProbe(),
                                       protector: MockFileProtector())
        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertTrue(report.adoptedOrphans.isEmpty)
        XCTAssertTrue(report.imported.isEmpty)
        XCTAssertTrue(report.alreadyPresent.isEmpty)
        XCTAssertNil(try fetchCapture(id, in: container))
    }

    func testAudioRemovalFailureKeepsRecord() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        let stubs = try stubFiles(files, id: id)

        XCTAssertThrowsError(
            try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container) { url in
                if url == stubs.audio { throw RemovalFailure() }
                try FileManager.default.removeItem(at: url)
            }
        ) { error in
            XCTAssertEqual(error as? CaptureDeleteError, .fileRemovalFailed)
        }

        XCTAssertNotNil(try fetchCapture(id, in: container))
        XCTAssertTrue(exists(stubs.audio))

        // The order is what keeps this safe: had the record gone first, pass 2 would adopt the audio.
        let importer = JournalImporter(files: files, durationProbe: MockDurationProbe(),
                                       protector: MockFileProtector())
        let report = importer.importAll(into: container, excluding: nil)
        XCTAssertTrue(report.adoptedOrphans.isEmpty)
        XCTAssertTrue(report.imported.isEmpty)
        let cid = id
        let all = try ModelContext(container).fetch(
            FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })
        )
        XCTAssertEqual(all.count, 1)
    }

    func testJournalRemovalFailureTouchesNothingAfter() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        let stubs = try stubFiles(files, id: id)

        XCTAssertThrowsError(
            try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container) { url in
                if url == stubs.journal { throw RemovalFailure() }
                try FileManager.default.removeItem(at: url)
            }
        ) { error in
            XCTAssertEqual(error as? CaptureDeleteError, .fileRemovalFailed)
        }

        XCTAssertTrue(exists(stubs.audio))
        XCTAssertTrue(exists(stubs.bad))
        XCTAssertNotNil(try fetchCapture(id, in: container))
    }

    func testRetryAfterPartialFailureSucceeds() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        let stubs = try stubFiles(files, id: id)

        XCTAssertThrowsError(
            try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container) { url in
                if url == stubs.audio { throw RemovalFailure() }
                try FileManager.default.removeItem(at: url)
            }
        ) { error in
            XCTAssertEqual(error as? CaptureDeleteError, .fileRemovalFailed)
        }
        // The journals went first, so the retry finds them already gone.
        XCTAssertFalse(exists(stubs.journal))
        XCTAssertFalse(exists(stubs.bad))

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)

        XCTAssertNil(try fetchCapture(id, in: container))
        XCTAssertFalse(exists(stubs.audio))
        XCTAssertFalse(exists(stubs.journal))
        XCTAssertFalse(exists(stubs.bad))
    }

    func testMissingFilesStillDeleteRecord() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)

        XCTAssertNil(try fetchCapture(id, in: container))
    }

    func testDeleteRefusesFiledCapture() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        let capture = try insertCapture(in: container, id: id)
        let episode = Episode(typedTitle: "The porch")
        container.mainContext.insert(episode)
        episode.captures.append(capture)
        XCTAssertNotNil(capture.episode)
        try container.mainContext.save()
        let stubs = try stubFiles(files, id: id)

        XCTAssertThrowsError(
            try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)
        ) { error in
            XCTAssertEqual(error as? CaptureDeleteError, .filed)
        }

        XCTAssertNotNil(try fetchCapture(id, in: container))
        XCTAssertTrue(exists(stubs.audio))
        XCTAssertTrue(exists(stubs.journal))
        XCTAssertTrue(exists(stubs.bad))
    }

    func testDeleteRefusesActiveCapture() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        let stubs = try stubFiles(files, id: id)

        XCTAssertThrowsError(
            try CaptureDeleter.delete(captureID: id, activeCaptureID: id, files: files, in: container)
        ) { error in
            XCTAssertEqual(error as? CaptureDeleteError, .active)
        }

        XCTAssertNotNil(try fetchCapture(id, in: container))
        XCTAssertTrue(exists(stubs.audio))
        XCTAssertTrue(exists(stubs.journal))
        XCTAssertTrue(exists(stubs.bad))
    }

    func testDeleteOfAbsentCaptureIsSuccess() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()

        XCTAssertNoThrow(
            try CaptureDeleter.delete(captureID: UUID(), activeCaptureID: nil, files: files, in: container)
        )
    }

    func testFilePassResultAfterDeleteIsNoOp() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let id = UUID()
        _ = try insertCapture(in: container, id: id)
        _ = try stubFiles(files, id: id)

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)
        let segments = [TranscriptSegment(text: "late words", start: 0, end: 2, isFinal: true)]
        CaptureCoordinator.applyFilePassResult(captureID: id, segments: segments, in: container)

        XCTAssertNil(try fetchCapture(id, in: container))
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Capture>()).count, 0)
    }

    func testDeleteLeavesAnsweredQuestionOpen() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let files = try makeFiles()
        let context = container.mainContext
        let period = Period(title: "Childhood", sortOrder: 0)
        context.insert(period)
        let question = Question.fixture(text: "Who else comes to mind from that time?",
                                        templateID: "period.else", slots: [], cue: .period, origin: .deck)
        context.insert(question)
        question.period = period
        question.askedCount = 2
        let id = UUID()
        let capture = try insertCapture(in: container, id: id)
        capture.answersQuestionID = question.id
        try context.save()

        try CaptureDeleter.delete(captureID: id, activeCaptureID: nil, files: files, in: container)

        let questionID = question.id
        let descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.id == questionID })
        let saved = try XCTUnwrap(try ModelContext(container).fetch(descriptor).first)
        XCTAssertEqual(saved.status, .open)
        XCTAssertEqual(saved.askedCount, 2)
    }
}
