import Foundation
import Speech

/// Probes the five inputs of TranscriptionRoute.select (spec 4.2) and returns the checked
/// route. Also serves as the coordinator's routeProvider.
struct SpeechRouteProbe: Sendable {
    func currentRoute() async -> TranscriptionRoute {
        let speechModuleAvailable = SpeechTranscriber.isAvailable
        let speechLocale = await SpeechTranscriber.supportedLocale(equivalentTo: .current)?
            .identifier(.bcp47)
        let speechAssetsInstalled: Bool
        if let speechLocale,
           let module = SpeechModules.module(for: .speech(localeID: speechLocale), live: false) {
            speechAssetsInstalled = await AssetInventory.status(forModules: [module]) == .installed
        } else {
            speechAssetsInstalled = false
        }
        let dictationLocale = await DictationTranscriber.supportedLocale(equivalentTo: .current)?
            .identifier(.bcp47)
        let dictationAssetsInstalled: Bool
        if let dictationLocale,
           let module = SpeechModules.module(for: .dictation(localeID: dictationLocale), live: false) {
            dictationAssetsInstalled = await AssetInventory.status(forModules: [module]) == .installed
        } else {
            dictationAssetsInstalled = false
        }
        return TranscriptionRoute.select(
            speechModuleAvailable: speechModuleAvailable,
            speechLocale: speechLocale,
            speechAssetsInstalled: speechAssetsInstalled,
            dictationLocale: dictationLocale,
            dictationAssetsInstalled: dictationAssetsInstalled)
    }
}
