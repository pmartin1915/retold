import Foundation

enum AudioOnlyReason: String, Equatable, Sendable, CaseIterable {
    case notChecked, noLocale, assetsNotInstalled, transcriberUnavailable
}

enum TranscriptionRoute: Equatable, Sendable {
    case speech(localeID: String)        // SpeechTranscriber
    case dictation(localeID: String)     // DictationTranscriber, the older-device fallback
    case audioOnly(AudioOnlyReason)

    /// "speech:<id>", "dictation:<id>", "audioOnly:<reason rawValue>".
    var journalTag: String {
        switch self {
        case .speech(let localeID): return "speech:\(localeID)"
        case .dictation(let localeID): return "dictation:\(localeID)"
        case .audioOnly(let reason): return "audioOnly:\(reason.rawValue)"
        }
    }

    /// The exact inverse of journalTag; nil for anything else (incl. empty locale id).
    init?(journalTag: String) {
        if let rest = journalTag.splitOnce(prefix: "speech:") {
            guard !rest.isEmpty else { return nil }
            self = .speech(localeID: rest)
        } else if let rest = journalTag.splitOnce(prefix: "dictation:") {
            guard !rest.isEmpty else { return nil }
            self = .dictation(localeID: rest)
        } else if let rest = journalTag.splitOnce(prefix: "audioOnly:") {
            guard let reason = AudioOnlyReason(rawValue: rest) else { return nil }
            self = .audioOnly(reason)
        } else {
            return nil
        }
    }

    /// The checked chain. R6b probes each input; none is assumed (PLAN §8 fallback chain).
    static func select(speechModuleAvailable: Bool, speechLocale: String?, speechAssetsInstalled: Bool,
                       dictationLocale: String?, dictationAssetsInstalled: Bool) -> TranscriptionRoute {
        if speechModuleAvailable, let speechLocale, speechAssetsInstalled {
            return .speech(localeID: speechLocale)
        }
        if let dictationLocale, dictationAssetsInstalled {
            return .dictation(localeID: dictationLocale)
        }
        let speechAssetsMissing = speechModuleAvailable && speechLocale != nil && !speechAssetsInstalled
        let dictationAssetsMissing = dictationLocale != nil && !dictationAssetsInstalled
        if speechAssetsMissing || dictationAssetsMissing {
            return .audioOnly(.assetsNotInstalled)
        }
        if speechModuleAvailable {
            return .audioOnly(.noLocale)
        }
        return .audioOnly(.transcriberUnavailable)
    }
}

private extension String {
    func splitOnce(prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
