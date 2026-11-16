import Foundation
import WhisperKit

// Whisper on the phone (WhisperKit, argmaxinc, MIT; pinned in project.yml). Since 1.1.0 it makes the
// kept transcript after Stop when the user has downloaded the model (docs/WHISPER-PASS-SPEC.md); the
// Listening self-test uses the same store and runner. The model download, from Hugging Face's
// argmaxinc/whisperkit-coreml, is the only network use. Audio never leaves the phone.

/// One Whisper model.
struct WhisperModelSpec: Sendable {
    let name: String          // report label
    let variant: String       // folder in argmaxinc/whisperkit-coreml
    let approxMB: Int         // download size, for the space check and the UI

    /// The app's model: large-v3-turbo quantized (1.2% WER, names right, 4.06 s per audio minute on
    /// the 21.1 self-test, 2026-11-16).
    static let turbo = WhisperModelSpec(name: "whisper-turbo-632MB",
                                        variant: "openai_whisper-large-v3-v20240930_turbo_632MB", approxMB: 632)

    /// The self-test compares turbo with a small English model.
    static let candidates: [WhisperModelSpec] = [
        turbo,
        WhisperModelSpec(name: "whisper-base.en", variant: "openai_whisper-base.en", approxMB: 150),
    ]

    static var totalMB: Int { candidates.reduce(0) { $0 + $1.approxMB } }
}

enum WhisperModelStore {
    /// Application Support/WhisperModels, excluded from backup.
    static var directory: URL? {
        guard var url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
            .appendingPathComponent("WhisperModels", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    /// Free space for important data, in MB (nil if unknown).
    static var freeMB: Int? {
        guard let directory,
              let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Int(bytes / 1_048_576)
    }

    static var downloadedMB: Int {
        guard let directory,
              let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        var total = 0
        for case let url as URL in enumerator {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total / 1_048_576
    }

    /// The folder of a completed download, if its marker and folder both exist. The marker is
    /// written only after a finished download (the app also waits for the first load), so a
    /// half-finished one is never used.
    static func downloadedFolder(for spec: WhisperModelSpec) -> URL? {
        // The marker holds the path relative to the store: the app container can move on update.
        guard let directory, let marker = marker(for: spec),
              let relative = try? String(contentsOf: marker, encoding: .utf8) else { return nil }
        let folder = directory.appendingPathComponent(relative, isDirectory: true)
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    static func recordDownload(of spec: WhisperModelSpec, at folder: URL) {
        guard let directory, let marker = marker(for: spec) else { return }
        let base = directory.standardizedFileURL.resolvingSymlinksInPath().path
        let full = folder.standardizedFileURL.resolvingSymlinksInPath().path
        guard full.hasPrefix(base + "/") else { return }     // outside the store: never cached
        try? String(full.dropFirst(base.count + 1)).write(to: marker, atomically: true, encoding: .utf8)
    }

    private static func marker(for spec: WhisperModelSpec) -> URL? {
        directory?.appendingPathComponent(spec.variant + ".downloaded")
    }

    /// Downloads `spec` into the store, after a free-space check. Does not write the marker.
    static func download(_ spec: WhisperModelSpec,
                         progress: @escaping @Sendable (_ tenth: Int) -> Void) async throws -> URL {
        guard let base = directory else { throw WhisperEngineError.noStorage }
        // Space for the download plus room to compile the model on first load.
        let needed = spec.approxMB * 2
        if let free = freeMB, free < needed {
            throw WhisperEngineError.notEnoughSpace(neededMB: needed, freeMB: free)
        }
        let lastTenth = LockedInt()
        return try await WhisperKit.download(variant: spec.variant, downloadBase: base,
                                             progressCallback: { fraction in
            let tenth = Int(fraction.fractionCompleted * 10)
            if lastTenth.advance(to: tenth) {
                progress(tenth)
            }
        })
    }

    static func deleteAll() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}

enum WhisperEngineError: LocalizedError {
    case noStorage
    case notEnoughSpace(neededMB: Int, freeMB: Int)
    case notLoaded
    case notDownloaded

    var errorDescription: String? {
        switch self {
        case .noStorage: return "No place to store the model."
        case .notEnoughSpace(let needed, let free):
            return "Not enough free space: the model needs about \(needed) MB, the phone has \(free) MB free."
        case .notLoaded: return "The model is not loaded."
        case .notDownloaded: return "The model is not on this phone."
        }
    }
}

/// Loads one Whisper model from a folder, transcribes files, unloads. @unchecked Sendable: `pipe` is
/// set by load and read by transcribe/unload, which every caller makes one at a time, in that order.
final class WhisperRunner: @unchecked Sendable {
    let spec: WhisperModelSpec
    private var pipe: WhisperKit?

    init(spec: WhisperModelSpec) {
        self.spec = spec
    }

    /// Loads (and on the first load, compiles) the model in `folder`; returns the seconds it took.
    func load(folder: URL) async throws -> Double {
        guard let base = WhisperModelStore.directory else { throw WhisperEngineError.noStorage }
        let loadStart = Date()
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine or Metal-backed Core ML: CPU only (the CI harness, 2026-11-15).
        let compute: ModelComputeOptions? = ModelComputeOptions(melCompute: .cpuOnly, audioEncoderCompute: .cpuOnly,
                                                               textDecoderCompute: .cpuOnly)
        #else
        let compute: ModelComputeOptions? = nil   // WhisperKit's defaults on the phone, unchanged
        #endif
        let config = WhisperKitConfig(model: spec.variant, downloadBase: base, modelFolder: folder.path,
                                      computeOptions: compute,
                                      verbose: false, prewarm: true, load: true, download: false)
        pipe = try await WhisperKit(config)
        return Date().timeIntervalSince(loadStart)
    }

    /// One file, English, voice-activity chunking. Segments in audio-file time, text trimmed, empty
    /// segments dropped. The words are Whisper's, verbatim (Rule 1: nothing here edits them).
    func transcribe(audioURL: URL) async throws -> [TranscriptSegment] {
        guard let pipe else { throw WhisperEngineError.notLoaded }
        let options = DecodingOptions(verbose: false, language: "en", skipSpecialTokens: true,
                                      chunkingStrategy: .vad)
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.flatMap(\.segments).compactMap { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TranscriptSegment(text: text, start: TimeInterval(segment.start),
                                     end: TimeInterval(segment.end), isFinal: true)
        }
    }

    func unload() async {
        await pipe?.unloadModels()
        pipe = nil
    }
}

/// Download progress arrives on any thread; report each tenth once.
final class LockedInt: @unchecked Sendable {
    private let lock = NSLock()
    private var value = -1
    func advance(to new: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard new > value else { return false }
        value = new
        return true
    }
}
