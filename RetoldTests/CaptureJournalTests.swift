import Foundation
import XCTest
@testable import Retold

/// The sidecar journal: record bytes, writer behaviour, reader salvage rules
/// (docs/R6-RECORDER-SPEC.md §3 and §6).
final class CaptureJournalTests: XCTestCase {
    private let captureID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let otherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let questionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeFiles() -> CaptureFiles {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("retold-journal-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return CaptureFiles(root: root)
    }

    // MARK: - Golden bytes

    func testRecordLineGolden() throws {
        // Key order is .sortedKeys; dates are .secondsSince1970; nil fields are omitted.
        let cases: [(JournalRecord, String)] = [
            (.begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                    createdAt: date, answering: nil, route: .speech(localeID: "en_US")),
             #"{"audioFileName":"00000000-0000-0000-0000-000000000001.m4a","captureID":"00000000-0000-0000-0000-000000000001","createdAt":1700000000,"kind":"begin","route":"speech:en_US","v":1}"#),
            (.runStarted(captureID, run: 0, audioOffset: 0),
             #"{"audioOffset":0,"captureID":"00000000-0000-0000-0000-000000000001","kind":"runStarted","run":0,"v":1}"#),
            (.segment(captureID, run: 0,
                      segment: TranscriptSegment(text: "hello", start: 1, end: 2, isFinal: true)),
             #"{"captureID":"00000000-0000-0000-0000-000000000001","end":2,"kind":"segment","run":0,"start":1,"text":"hello","v":1}"#),
            (.transcriberEnded(captureID, run: 0, completed: true),
             #"{"captureID":"00000000-0000-0000-0000-000000000001","completed":true,"kind":"transcriberEnded","run":0,"v":1}"#),
            (.paused(captureID, at: date),
             #"{"at":1700000000,"captureID":"00000000-0000-0000-0000-000000000001","kind":"paused","v":1}"#),
            (.resumed(captureID, at: date),
             #"{"at":1700000000,"captureID":"00000000-0000-0000-0000-000000000001","kind":"resumed","v":1}"#),
            (.end(captureID, duration: 30, reason: .userStop, endedAt: date),
             #"{"at":1700000000,"captureID":"00000000-0000-0000-0000-000000000001","duration":30,"kind":"end","reason":"userStop","v":1}"#),
        ]
        for (record, expected) in cases {
            XCTAssertEqual(try JournalCoding.line(record), Data((expected + "\n").utf8))
        }
        // begin carries answersQuestionID when answering is non-nil.
        let answering = JournalRecord.begin(
            captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
            createdAt: date, answering: questionID, route: .audioOnly(.notChecked))
        let line = String(decoding: try JournalCoding.line(answering), as: UTF8.self)
        XCTAssertTrue(line.hasPrefix(
            #"{"answersQuestionID":"00000000-0000-0000-0000-000000000003","#))
        XCTAssertTrue(line.contains(#""route":"audioOnly:notChecked""#))
    }

    // MARK: - Round trip

    func testRoundTripEveryKind() throws {
        let records = [
            JournalRecord.begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                                createdAt: date, answering: questionID,
                                route: .dictation(localeID: "fr_FR")),
            JournalRecord.runStarted(captureID, run: 0, audioOffset: 0),
            JournalRecord.segment(captureID, run: 0,
                                  segment: TranscriptSegment(text: "café 🙂", start: 0.5,
                                                             end: 2.25, isFinal: true)),
            JournalRecord.transcriberEnded(captureID, run: 0, completed: false),
            JournalRecord.paused(captureID, at: date),
            JournalRecord.resumed(captureID, at: date),
            JournalRecord.end(captureID, duration: 42.5, reason: .mediaServicesReset, endedAt: date),
            JournalRecord.end(captureID, duration: 1800, reason: .timeLimit, endedAt: date),   // §7a
        ]
        for record in records {
            let data = try JournalCoding.line(record)
            let decoded = try JournalCoding.decoder().decode(
                JournalRecord.self, from: data.dropLast())
            XCTAssertEqual(decoded, record)
        }
    }

    // MARK: - Writer

    private func makeWriter(_ files: CaptureFiles,
                            protector: MockFileProtector? = nil) throws -> JournalWriter {
        let files = files
        try files.prepare()
        return try JournalWriter(files: files, captureID: captureID,
                                 protector: protector ?? MockFileProtector())
    }

    private func sampleRecords() -> [JournalRecord] {
        [
            .begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                   createdAt: date, answering: nil, route: .audioOnly(.notChecked)),
            .runStarted(captureID, run: 0, audioOffset: 0),
            .segment(captureID, run: 0,
                     segment: TranscriptSegment(text: "one", start: 0, end: 1, isFinal: true)),
            .segment(captureID, run: 0,
                     segment: TranscriptSegment(text: "two", start: 1, end: 2, isFinal: true)),
            .end(captureID, duration: 2, reason: .userStop, endedAt: date),
        ]
    }

    func testWriterAppendsAndReaderReplaysInOrder() throws {
        let files = makeFiles()
        let writer = try makeWriter(files)
        let records = sampleRecords()
        for record in records {
            try writer.append(record)
        }
        writer.close()

        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.captureID, captureID)
        XCTAssertEqual(replay.records, records)
        XCTAssertFalse(replay.droppedTornTail)
        XCTAssertNil(replay.corruptLine)
    }

    func testWriterRejectsWrongCapture() throws {
        let files = makeFiles()
        let writer = try makeWriter(files)
        defer { writer.close() }
        XCTAssertThrowsError(try writer.append(.begin(
            otherID, audioFileName: CaptureFiles.audioFileName(for: otherID),
            createdAt: date, answering: nil, route: .audioOnly(.notChecked)))) { error in
            XCTAssertEqual(error as? JournalError, .wrongCapture)
        }
    }

    func testWriterRejectsAfterClose() throws {
        let files = makeFiles()
        let writer = try makeWriter(files)
        writer.close()
        XCTAssertThrowsError(try writer.append(sampleRecords()[0])) { error in
            XCTAssertEqual(error as? JournalError, .closed)
        }
        // close() is idempotent.
        writer.close()
    }

    func testWriterRefusesExistingFile() throws {
        let files = makeFiles()
        let first = try makeWriter(files)
        defer { first.close() }
        XCTAssertThrowsError(try JournalWriter(files: files, captureID: captureID,
                                               protector: MockFileProtector())) { error in
            XCTAssertEqual(error as? JournalError, .alreadyExists)
        }
    }

    func testWriterRequestsCompleteUnlessOpen() throws {
        let files = makeFiles()
        let protector = MockFileProtector()
        let writer = try makeWriter(files, protector: protector)
        writer.close()
        XCTAssertEqual(protector.calls.count, 1)
        XCTAssertEqual(protector.calls[0].url, files.journalURL(for: captureID))
        XCTAssertEqual(protector.calls[0].type, .completeUnlessOpen)
    }

    func testWriterRemovesFileWhenProtectFails() throws {
        let files = makeFiles()
        let protector = MockFileProtector()
        protector.failNext([JournalError.closed])
        XCTAssertThrowsError(try JournalWriter(files: files, captureID: captureID,
                                               protector: protector))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: files.journalURL(for: captureID).path))
    }

    // MARK: - Reader salvage rules

    /// Writes the given lines to the journal file (each string already "\n"-terminated or not).
    private func writeJournal(_ files: CaptureFiles, _ contents: String) throws {
        try files.prepare()
        try Data(contents.utf8).write(to: files.journalURL(for: captureID))
    }

    func testCompleteLastLineWithoutNewlineIsKept() throws {
        let files = makeFiles()
        // Three records, the last with no trailing "\n" (a torn write that happened to be whole).
        let records = Array(sampleRecords().prefix(3))
        var text = ""
        for (index, record) in records.enumerated() {
            var line = String(decoding: try JournalCoding.line(record), as: UTF8.self)
            if index == records.count - 1 { line.removeLast() }
            text += line
        }
        try writeJournal(files, text)

        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, 3)
        XCTAssertFalse(replay.droppedTornTail)
        XCTAssertNil(replay.corruptLine)
    }

    func testTornTailIsDropped() throws {
        let files = makeFiles()
        let good = String(decoding: try JournalCoding.line(sampleRecords()[0]), as: UTF8.self)
            + String(decoding: try JournalCoding.line(sampleRecords()[1]), as: UTF8.self)
        try writeJournal(files, good + #"{"captureID":"00000000-0000-00"#)   // half a line
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, 2)
        XCTAssertTrue(replay.droppedTornTail)
        XCTAssertNil(replay.corruptLine)
    }

    func testCorruptMiddleLineSalvagesEarlierRecords() throws {
        let files = makeFiles()
        let records = sampleRecords()
        var text = ""
        for (index, record) in records.enumerated() {
            if index == 2 {
                text += "this is not json\n"      // physical line 3 of 5
            } else {
                text += String(decoding: try JournalCoding.line(record), as: UTF8.self)
            }
        }
        try writeJournal(files, text)
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, 2)
        XCTAssertEqual(replay.corruptLine, 3)
        XCTAssertFalse(replay.droppedTornTail)
    }

    func testUnknownVersionIsUndecodable() throws {
        let files = makeFiles()
        let begin = String(decoding: try JournalCoding.line(sampleRecords()[0]), as: UTF8.self)
        // Same shape as a record but v: 2; as the LAST line it is dropped as torn.
        let v2 = #"{"captureID":"00000000-0000-0000-0000-000000000001","kind":"runStarted","run":0,"v":2}"#
        try writeJournal(files, begin + v2)
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, 1)
        XCTAssertTrue(replay.droppedTornTail)
        XCTAssertNil(replay.corruptLine)
    }

    func testUndecodableLastLineWithNewlineIsTorn() throws {
        let files = makeFiles()
        let begin = String(decoding: try JournalCoding.line(sampleRecords()[0]), as: UTF8.self)
        try writeJournal(files, begin + "{garbage}\n")
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.count, 1)
        XCTAssertTrue(replay.droppedTornTail)
        XCTAssertNil(replay.corruptLine)
    }

    func testMissingBeginThrows() throws {
        let files = makeFiles()
        // Empty file.
        try writeJournal(files, "")
        XCTAssertThrowsError(try JournalReader.read(files.journalURL(for: captureID))) { error in
            XCTAssertEqual(error as? JournalError, .missingBegin)
        }
        // First decodable record is a segment.
        let segment = String(decoding: try JournalCoding.line(sampleRecords()[2]), as: UTF8.self)
        try writeJournal(files, segment)
        XCTAssertThrowsError(try JournalReader.read(files.journalURL(for: captureID))) { error in
            XCTAssertEqual(error as? JournalError, .missingBegin)
        }
    }

    func testMixedCapturesThrows() throws {
        let files = makeFiles()
        let begin = String(decoding: try JournalCoding.line(sampleRecords()[0]), as: UTF8.self)
        let other = String(decoding: try JournalCoding.line(.runStarted(otherID, run: 0, audioOffset: 0)),
                           as: UTF8.self)
        try writeJournal(files, begin + other)
        XCTAssertThrowsError(try JournalReader.read(files.journalURL(for: captureID))) { error in
            XCTAssertEqual(error as? JournalError, .mixedCaptures(line: 2))
        }
    }

    func testNewlineInTextStaysOneLine() throws {
        let files = makeFiles()
        let writer = try makeWriter(files)
        defer { writer.close() }
        let record = JournalRecord.segment(
            captureID, run: 0,
            segment: TranscriptSegment(text: "a\nb", start: 0, end: 1, isFinal: true))
        try writer.append(.begin(captureID, audioFileName: CaptureFiles.audioFileName(for: captureID),
                                 createdAt: Date(timeIntervalSince1970: 0), answering: nil,
                                 route: .speech(localeID: "en_US")))
        try writer.append(record)
        writer.close()

        let raw = try String(contentsOf: files.journalURL(for: captureID), encoding: .utf8)
        XCTAssertEqual(raw.filter { $0 == "\n" }.count, 2)   // begin line + segment line
        let replay = try JournalReader.read(files.journalURL(for: captureID))
        XCTAssertEqual(replay.records.last?.text, "a\nb")
    }

    func testJournalURLsSortedAndSkipBad() throws {
        let files = makeFiles()
        try files.prepare()
        let ids = [UUID(), UUID(), UUID()].sorted { $0.uuidString < $1.uuidString }
        for id in ids {
            let writer = try JournalWriter(files: files, captureID: id, protector: MockFileProtector())
            writer.close()
        }
        // A quarantined journal is not listed.
        try Data().write(to: files.journalURL(for: ids[1]).appendingPathExtension("bad"))

        let urls = try JournalReader.journalURLs(in: files)
        XCTAssertEqual(urls.map(\.lastPathComponent),
                       ids.map { "\($0.uuidString).jsonl" })
        // And captureID(fromFileName:) decodes all three shapes.
        for id in ids {
            XCTAssertEqual(CaptureFiles.captureID(fromFileName: "\(id.uuidString).m4a"), id)
            XCTAssertEqual(CaptureFiles.captureID(fromFileName: "\(id.uuidString).jsonl"), id)
            XCTAssertEqual(CaptureFiles.captureID(fromFileName: "\(id.uuidString).jsonl.bad"), id)
        }
        XCTAssertNil(CaptureFiles.captureID(fromFileName: "notes.txt"))
    }
}
