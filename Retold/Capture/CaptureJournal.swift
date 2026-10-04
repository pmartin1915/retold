import Foundation

// The sidecar journal: JSON Lines, one record per line, append-only. The SwiftData store is
// .complete (unwritable while locked), so a capture writes only its audio file and this journal,
// both .completeUnlessOpen; the importer touches the store only while protected data is available.

struct JournalRecord: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case begin, runStarted, segment, transcriberEnded, paused, resumed, end }

    let v: Int                            // format version, 1
    let kind: Kind
    let captureID: UUID
    var audioFileName: String? = nil      // begin
    var createdAt: Date? = nil            // begin
    var answersQuestionID: UUID? = nil    // begin
    var route: String? = nil              // begin: TranscriptionRoute.journalTag
    var run: Int? = nil                   // runStarted, segment, transcriberEnded
    var audioOffset: TimeInterval? = nil  // runStarted
    var text: String? = nil               // segment (audio-file time)
    var start: TimeInterval? = nil        // segment
    var end: TimeInterval? = nil          // segment
    var completed: Bool? = nil            // transcriberEnded
    var at: Date? = nil                   // paused, resumed, end (= endedAt)
    var duration: TimeInterval? = nil     // end
    var reason: CaptureEndReason? = nil   // end

    static func begin(_ id: UUID, audioFileName: String, createdAt: Date, answering: UUID?,
                      route: TranscriptionRoute) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .begin, captureID: id)
        r.audioFileName = audioFileName
        r.createdAt = createdAt
        r.answersQuestionID = answering
        r.route = route.journalTag
        return r
    }

    static func runStarted(_ id: UUID, run: Int, audioOffset: TimeInterval) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .runStarted, captureID: id)
        r.run = run
        r.audioOffset = audioOffset
        return r
    }

    static func segment(_ id: UUID, run: Int, segment: TranscriptSegment) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .segment, captureID: id)
        r.run = run
        r.text = segment.text
        r.start = segment.start
        r.end = segment.end
        return r
    }

    static func transcriberEnded(_ id: UUID, run: Int, completed: Bool) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .transcriberEnded, captureID: id)
        r.run = run
        r.completed = completed
        return r
    }

    static func paused(_ id: UUID, at: Date) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .paused, captureID: id)
        r.at = at
        return r
    }

    static func resumed(_ id: UUID, at: Date) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .resumed, captureID: id)
        r.at = at
        return r
    }

    static func end(_ id: UUID, duration: TimeInterval, reason: CaptureEndReason, endedAt: Date) -> JournalRecord {
        var r = JournalRecord(v: 1, kind: .end, captureID: id)
        r.duration = duration
        r.reason = reason
        r.at = endedAt
        return r
    }
}

enum JournalCoding {
    /// outputFormatting [.sortedKeys, .withoutEscapingSlashes]; dateEncodingStrategy .secondsSince1970.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    /// dateDecodingStrategy .secondsSince1970.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Encoded record + "\n".
    static func line(_ record: JournalRecord) throws -> Data {
        var data = try encoder().encode(record)
        data.append(0x0A) // "\n"
        return data
    }
}

// MARK: - Writer

/// One capture's open journal (the coordinator's seam; the mock throws on demand).
protocol JournalAppending: AnyObject {
    var captureID: UUID { get }
    func append(_ record: JournalRecord) throws
    func close()
}

enum JournalError: Error, Equatable {
    case wrongCapture, closed, alreadyExists
    case missingBegin                  // no decodable records, or the first is not .begin
    case mixedCaptures(line: Int)      // a record's captureID differs from begin's
}

final class JournalWriter: JournalAppending {
    let captureID: UUID
    private let handle: FileHandle
    private var isClosed = false

    /// Exclusive create + open in one step: open(2) with O_WRONLY|O_CREAT|O_EXCL|O_APPEND, mode
    /// 0o600 (EEXIST -> JournalError.alreadyExists); then protect the file for recording. If
    /// protect throws the file is closed and removed. The handle stays open until close().
    init(files: CaptureFiles, captureID: UUID, protector: any FileProtector) throws {
        self.captureID = captureID
        let url = files.journalURL(for: captureID)
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_APPEND, 0o600)
        if fd == -1 {
            if errno == EEXIST { throw JournalError.alreadyExists }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        self.handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try protector.protect(url, as: ProtectionPlan.whileRecording)
        } catch {
            handle.closeFile()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// Writes JournalCoding.line(record) in one write, then synchronize().
    func append(_ record: JournalRecord) throws {
        if isClosed { throw JournalError.closed }
        if record.captureID != captureID { throw JournalError.wrongCapture }
        try handle.write(contentsOf: JournalCoding.line(record))
        try handle.synchronize()
    }

    /// Idempotent.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        handle.closeFile()
    }
}

// MARK: - Reader

struct JournalReplay: Equatable, Sendable {
    let captureID: UUID
    let records: [JournalRecord]       // every good record before the first bad line
    let droppedTornTail: Bool          // the last physical line was undecodable and was dropped
    let corruptLine: Int?              // 1-based physical line (empty lines counted) of the first
                                       // undecodable line that is NOT the last; records after it
                                       // are not read
}

enum JournalReader {
    /// Splits on "\n". Empty lines are skipped (but counted for line numbers). A last line (with or
    /// without a trailing "\n") that decodes is KEPT; one that does not decode is dropped
    /// (droppedTornTail = true). The first undecodable non-last line sets corruptLine and stops
    /// reading; the records before it are returned (salvage). Throws only .missingBegin and
    /// .mixedCaptures.
    static func read(_ url: URL) throws -> JournalReplay {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var records: [JournalRecord] = []
        var droppedTornTail = false
        var corruptLine: Int? = nil
        var captureID: UUID? = nil

        // "Last" is the last NON-empty line: a file ending in "\n" splits to a trailing "".
        let lastNonEmptyIndex = lines.lastIndex { !$0.isEmpty }
        for (index, line) in lines.enumerated() where !line.isEmpty {
            let lineNumber = index + 1
            let isLast = index == lastNonEmptyIndex
            guard let record = decodeLine(line) else {
                if isLast {
                    droppedTornTail = true
                } else {
                    corruptLine = lineNumber
                }
                break
            }
            if captureID == nil {
                guard record.kind == .begin else { throw JournalError.missingBegin }
                captureID = record.captureID
            } else if record.captureID != captureID {
                throw JournalError.mixedCaptures(line: lineNumber)
            }
            records.append(record)
        }

        // An empty file (or one with only empty lines) has no decodable records at all.
        guard let captureID, !records.isEmpty else { throw JournalError.missingBegin }
        return JournalReplay(captureID: captureID, records: records,
                             droppedTornTail: droppedTornTail, corruptLine: corruptLine)
    }

    /// journal/*.jsonl (not *.bad), sorted by file name.
    static func journalURLs(in files: CaptureFiles) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: files.journalDirectory, includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.lastPathComponent.hasSuffix(".jsonl") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// A line decodes only if it is a JournalRecord with v == 1 (§3.2: any other version is
    /// undecodable for the reader).
    private static func decodeLine(_ line: String) -> JournalRecord? {
        guard let record = try? JournalCoding.decoder().decode(
            JournalRecord.self, from: Data(line.utf8)
        ), record.v == 1 else {
            return nil
        }
        return record
    }
}
