import Foundation
import os

// The after-Stop pass seam (docs/WHISPER-PASS-SPEC.md). The importer marks a capture whose live run
// completed when the model is on the phone; the coordinator's file pass then runs Whisper over the
// saved audio and completes the capture with Whisper's words, or with Apple's on any fallback.

/// What the coordinator needs from Whisper. The real one is WhisperAfterStopPass; tests use a mock.
protocol AfterStopPass: Sendable {
    /// The model is on the phone. Cheap and synchronous: the importer calls it inside its import.
    func isReady() -> Bool
    /// Memory this process may still use, in MB; nil when there is no such limit (simulator).
    func availableMemoryMB() -> Int?
    /// Loads the model, transcribes the file, unloads (also on error or cancellation).
    func transcribe(audioURL: URL) async throws -> [TranscriptSegment]
}

enum WhisperPassLimits {
    /// 674 MB measured peak on 21.1, plus margin.
    static let requiredMemoryMB = 1_000
    /// Passes started for one capture before it keeps Apple's transcript. A pass the process did not
    /// survive (jetsam) runs no fallback code, so only this count ends the loop.
    static let attemptCap = 2

    /// 60 s plus 15 s per audio minute (measured: 3.1 s load, 4.06 s per minute).
    static func timeLimit(duration: TimeInterval) -> TimeInterval {
        60 + 15 * max(0, duration) / 60
    }

    /// Whisper is called with language "en"; other locales keep Apple's transcript.
    static func isEnglish(localeID: String) -> Bool {
        localeID.lowercased().hasPrefix("en")
    }

    /// Whisper's words replace Apple's only if there are some, and at least half as many: a
    /// hallucinated "Thank you." or a truncated pass never replaces a real transcript.
    static func accepts(whisper: [TranscriptSegment], apple: [TranscriptSegment]) -> Bool {
        let whisperWords = wordCount(whisper)
        guard whisperWords > 0 else { return false }
        return whisperWords * 2 >= wordCount(apple)
    }

    static func wordCount(_ segments: [TranscriptSegment]) -> Int {
        segments.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }
}

/// Which captures wait for the Whisper pass, and how many passes each has started. UserDefaults, not
/// the store: readable while the phone is locked, and no schema change. A lost entry is safe (the
/// capture gets today's Apple file pass); a stale one is pruned. @unchecked Sendable: UserDefaults
/// is thread-safe, and every caller is on the main actor anyway.
final class WhisperPassLedger: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "retold.whisperPass.pending") {
        self.defaults = defaults
        self.key = key
    }

    private var entries: [String: Int] {
        get { defaults.dictionary(forKey: key) as? [String: Int] ?? [:] }
        set {
            defaults.set(newValue, forKey: key)
            defaults.synchronize()   // the attempt count must survive a kill that follows at once
        }
    }

    var markedIDs: Set<UUID> { Set(entries.keys.compactMap(UUID.init(uuidString:))) }

    func mark(_ id: UUID) { entries[id.uuidString] = 0 }
    func isMarked(_ id: UUID) -> Bool { entries[id.uuidString] != nil }
    func attempts(_ id: UUID) -> Int { entries[id.uuidString] ?? 0 }
    func remove(_ id: UUID) { entries[id.uuidString] = nil }

    func beginAttempt(_ id: UUID) {
        guard let count = entries[id.uuidString] else { return }
        entries[id.uuidString] = count + 1
    }

    /// The pass returned without a result (a capture started, the phone locked): not a failure.
    func giveBack(_ id: UUID) {
        guard let count = entries[id.uuidString] else { return }
        entries[id.uuidString] = max(0, count - 1)
    }

    /// Drops entries whose capture is gone or no longer waiting.
    func prune(keeping waiting: Set<UUID>) {
        let kept = entries.filter { key, _ in UUID(uuidString: key).map(waiting.contains) ?? false }
        if kept.count != entries.count { entries = kept }
    }
}

/// The real pass: Whisper turbo from the store, loaded per capture and unloaded after it.
struct WhisperAfterStopPass: AfterStopPass {
    let spec = WhisperModelSpec.turbo

    func isReady() -> Bool {
        WhisperModelStore.downloadedFolder(for: spec) != nil
    }

    func availableMemoryMB() -> Int? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return Int(os_proc_available_memory() / 1_048_576)
        #endif
    }

    func transcribe(audioURL: URL) async throws -> [TranscriptSegment] {
        guard let folder = WhisperModelStore.downloadedFolder(for: spec) else {
            throw WhisperEngineError.notDownloaded
        }
        let runner = WhisperRunner(spec: spec)
        do {
            _ = try await runner.load(folder: folder)
            try Task.checkCancellation()
            let segments = try await runner.transcribe(audioURL: audioURL)
            await runner.unload()
            return segments
        } catch {
            await runner.unload()
            throw error
        }
    }
}
