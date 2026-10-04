import Foundation

/// Where a capture's files live. Production root: Application Support/Captures (R6b passes it);
/// tests pass a temp directory. Never Caches (purgeable; StoryCue S1 lesson).
struct CaptureFiles: Sendable, Equatable {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    var audioDirectory: URL { root.appendingPathComponent("audio", isDirectory: true) }
    var journalDirectory: URL { root.appendingPathComponent("journal", isDirectory: true) }

    func audioURL(for captureID: UUID) -> URL {
        audioDirectory.appendingPathComponent(CaptureFiles.audioFileName(for: captureID))
    }

    func journalURL(for captureID: UUID) -> URL {
        journalDirectory.appendingPathComponent("\(captureID.uuidString).jsonl")
    }

    /// "<uuidString>.m4a" — what Capture.audioFileName stores.
    static func audioFileName(for captureID: UUID) -> String {
        "\(captureID.uuidString).m4a"
    }

    /// The capture ID encoded in an audio or journal file name ("<uuid>.m4a", "<uuid>.jsonl",
    /// "<uuid>.jsonl.bad"), or nil.
    static func captureID(fromFileName name: String) -> UUID? {
        let stem: String?
        if name.hasSuffix(".jsonl.bad") {
            stem = String(name.dropLast(".jsonl.bad".count))
        } else if name.hasSuffix(".jsonl") {
            stem = String(name.dropLast(".jsonl".count))
        } else if name.hasSuffix(".m4a") {
            stem = String(name.dropLast(".m4a".count))
        } else {
            stem = nil
        }
        guard let stem else { return nil }
        return UUID(uuidString: stem)
    }

    /// Creates both directories (withIntermediateDirectories: true). Idempotent.
    func prepare() throws {
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
    }
}

/// The Data Protection class each file gets, and when (PLAN section 1, Data Protection row).
enum ProtectionPlan {
    /// The audio file and the journal at creation: an already-open file keeps being written while locked.
    static let whileRecording: FileProtectionType = .completeUnlessOpen
    /// The audio file once its capture is imported.
    static let afterImport: FileProtectionType = .complete
}
