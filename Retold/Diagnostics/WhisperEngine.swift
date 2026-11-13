import Foundation
import WhisperKit

// Whisper on the phone (WhisperKit, argmaxinc, MIT; pinned in project.yml), as an extra engine in
// the Listening self-test only (Perry's pick, 2026-11-12). The app's recording path stays on Apple's
// SpeechTranscriber until the self-test numbers decide. The model download, from Hugging Face's
// argmaxinc/whisperkit-coreml, happens only when the user starts the self-test with Whisper on, and
// it is the only network use. Audio never leaves the phone.

/// One Whisper model the self-test can try.
struct WhisperModelSpec: Sendable {
    let name: String          // report label
    let variant: String       // folder in argmaxinc/whisperkit-coreml
    let approxMB: Int         // download size, for the space check and the UI

    /// Large-v3-turbo quantized first (the full turbo is about 1.6 GB), then a small English model,
    /// so the size/accuracy trade shows up in the numbers.
    static let candidates: [WhisperModelSpec] = [
        WhisperModelSpec(name: "whisper-turbo-632MB",
                         variant: "openai_whisper-large-v3-v20240930_turbo_632MB", approxMB: 632),
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

    static func deleteAll() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}

enum WhisperEngineError: LocalizedError {
    case noStorage
    case notEnoughSpace(neededMB: Int, freeMB: Int)
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .noStorage: return "No place to store the model."
        case .notEnoughSpace(let needed, let free):
            return "Not enough free space: the model needs about \(needed) MB, the phone has \(free) MB free."
        case .notLoaded: return "The model is not loaded."
        }
    }
}

/// A HarnessFileEngine backed by WhisperKit. @unchecked Sendable: `pipe` is set by prepare and read
/// by transcribe/unload, which the harness calls one at a time, in that order.
final class WhisperEngine: HarnessFileEngine, @unchecked Sendable {
    let spec: WhisperModelSpec
    private var pipe: WhisperKit?

    var name: String { spec.name }
    var model: String { spec.variant }

    init(spec: WhisperModelSpec) {
        self.spec = spec
    }

    func prepare(progress: @escaping @Sendable (String) -> Void) async throws -> (download: Double, load: Double) {
        guard let base = WhisperModelStore.directory else { throw WhisperEngineError.noStorage }
        // Space for the download plus room to compile the model on first load.
        let needed = spec.approxMB * 2
        if let free = WhisperModelStore.freeMB, free < needed {
            throw WhisperEngineError.notEnoughSpace(neededMB: needed, freeMB: free)
        }
        let name = spec.name
        let downloadStart = Date()
        let lastTenth = LockedInt()
        let folder = try await WhisperKit.download(variant: spec.variant, downloadBase: base,
                                                   progressCallback: { fraction in
            let tenth = Int(fraction.fractionCompleted * 10)
            if lastTenth.advance(to: tenth) {
                progress("\(name): download \(tenth * 10)%")
            }
        })
        let download = Date().timeIntervalSince(downloadStart)
        progress("\(name): loading the model (the first load compiles it, which can take a few minutes)")
        let loadStart = Date()
        let config = WhisperKitConfig(model: spec.variant, downloadBase: base, modelFolder: folder.path,
                                      verbose: false, prewarm: true, load: true, download: false)
        pipe = try await WhisperKit(config)
        return (download, Date().timeIntervalSince(loadStart))
    }

    func transcribe(audioURL: URL) async throws -> [HarnessEvent] {
        guard let pipe else { throw WhisperEngineError.notLoaded }
        let options = DecodingOptions(verbose: false, language: "en", skipSpecialTokens: true,
                                      chunkingStrategy: .vad)
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.flatMap(\.segments).map { segment in
            HarnessEvent(kind: "final", text: segment.text.trimmingCharacters(in: .whitespaces),
                         start: Double(segment.start), end: Double(segment.end), wall: 0)
        }
    }

    func unload() async {
        await pipe?.unloadModels()
        pipe = nil
    }
}

/// Download progress arrives on any thread; report each tenth once.
private final class LockedInt: @unchecked Sendable {
    private let lock = NSLock()
    private var value = -1
    func advance(to new: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard new > value else { return false }
        value = new
        return true
    }
}
