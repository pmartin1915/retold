import Foundation
import os

/// Per-capture listening diagnostics (listening hardening, step 4): counts and timings only, never
/// words. Some causes show only on a real phone (mic route, Bluetooth, interruptions, an engine that
/// stops itself), so the live engine fills one of these per capture. Recorded only while
/// `CaptureStatsLog.enabled` (Debug and TestFlight builds), kept for the last `keep` captures in
/// Application Support, and shared by the user from the Listening self-test screen.
struct CaptureStats: Codable, Sendable {
    var startedAt: Date
    var route: String
    var inputFormat: String
    var transcriberStarted = false
    /// Tap buffers received, the longest wall-clock gap between two of them, and how many gaps
    /// exceeded one second. A long gap with no interruption means the engine stopped delivering.
    var buffers = 0
    var maxBufferGap = 0.0
    var gapsOverOneSecond = 0
    var convertDrops = 0
    var writeError = false
    var volatiles = 0
    var finals = 0
    var finalsAfterStop = 0
    /// Seconds from engine start to the first volatile and first final result.
    var firstVolatileAfter: Double?
    var firstFinalAfter: Double?
    var interruptions = 0
    var mediaResets = 0
    /// Engine configuration changes, how many kept the input format (the engine does not end the
    /// capture for those), and whether the engine was still running after each one.
    var configChanges = 0
    var configChangesSameFormat = 0
    var engineRunningAfterConfigChange: [Bool] = []
    var recordedSeconds = 0.0
    var wallSeconds = 0.0
    var stopToDone = 0.0
    var transcriberCompleted: Bool?
}

enum CaptureStatsLog {
    static let keep = 30
    private static let enabledFlag = OSAllocatedUnfairLock(initialState: false)
    private static let fileLock = OSAllocatedUnfairLock(initialState: ())

    static var enabled: Bool { enabledFlag.withLock { $0 } }
    static func setEnabled(_ on: Bool) { enabledFlag.withLock { $0 = on } }

    static var url: URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true) else { return nil }
        return support.appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("capture-stats.json")
    }

    static func load() -> [CaptureStats] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([CaptureStats].self, from: data)) ?? []
    }

    /// One serial background queue for the log file, so saving never delays the end of a capture
    /// (Sol review of PR #37: the write ran inside stop(), before engineStopped).
    private static let queue = DispatchQueue(label: "dev.pmartin1915.retold.capture-stats", qos: .utility)

    /// Appends one record and keeps the newest `keep`, on the background queue. Best effort:
    /// diagnostics never fail or delay a capture.
    static func append(_ stats: CaptureStats) {
        queue.async { appendNow(stats) }
    }

    private static func appendNow(_ stats: CaptureStats) {
        guard let url else { return }
        fileLock.withLock { _ in
            var all = load()
            all.append(stats)
            if all.count > keep { all.removeFirst(all.count - keep) }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            if let data = try? encoder.encode(all) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
