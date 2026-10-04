import Foundation
import Speech

/// Downloads and installs the on-device assets for the best available transcription module
/// (PLAN section 8). Runs after the microphone grant, off the UI path. Errors are swallowed:
/// the route then probes as .audioOnly(.assetsNotInstalled) and the file pass retries later.
struct AssetPrefetch: Sendable {
    func run() async {
        let module: (any SpeechModule)?
        if SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) {
            module = SpeechModules.module(for: .speech(localeID: locale.identifier(.bcp47)), live: false)
        } else if let locale = await DictationTranscriber.supportedLocale(equivalentTo: .current) {
            module = SpeechModules.module(for: .dictation(localeID: locale.identifier(.bcp47)), live: false)
        } else {
            module = nil
        }
        guard let module else { return }
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
        } catch {
            // Swallowed on purpose; see the type comment.
        }
    }
}
