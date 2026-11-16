import Foundation

// Whisper as an extra engine in the Listening self-test (Perry's pick, 2026-11-12). The model store
// and runner moved to Retold/Capture/Whisper/WhisperModel.swift when Whisper became the after-Stop
// pass (1.1.0, docs/WHISPER-PASS-SPEC.md); this is the harness's thin wrapper around them.

/// A HarnessFileEngine backed by WhisperRunner. @unchecked Sendable: the harness calls prepare,
/// transcribe and unload one at a time, in that order.
final class WhisperEngine: HarnessFileEngine, @unchecked Sendable {
    let spec: WhisperModelSpec
    private let runner: WhisperRunner

    var name: String { spec.name }
    var model: String { spec.variant }

    init(spec: WhisperModelSpec) {
        self.spec = spec
        self.runner = WhisperRunner(spec: spec)
    }

    func prepare(progress: @escaping @Sendable (String) -> Void) async throws -> (download: Double, load: Double) {
        let name = spec.name
        var download = 0.0
        let folder: URL
        if let cached = WhisperModelStore.downloadedFolder(for: spec) {
            // Already downloaded (Sol review of PR #37): load it with no network and no space check.
            progress("\(name): using the model already on this phone")
            folder = cached
        } else {
            let downloadStart = Date()
            folder = try await WhisperModelStore.download(spec) { tenth in
                progress("\(name): download \(tenth * 10)%")
            }
            download = Date().timeIntervalSince(downloadStart)
            WhisperModelStore.recordDownload(of: spec, at: folder)
        }
        progress("\(name): loading the model (the first load compiles it, which can take a few minutes)")
        let load = try await runner.load(folder: folder)
        return (download, load)
    }

    func transcribe(audioURL: URL) async throws -> [HarnessEvent] {
        try await runner.transcribe(audioURL: audioURL).map { segment in
            HarnessEvent(kind: "final", text: segment.text, start: segment.start, end: segment.end, wall: 0)
        }
    }

    func unload() async {
        await runner.unload()
    }
}
