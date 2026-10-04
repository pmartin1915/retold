import Foundation

/// Retold's mirror of the model's availability (PLAN section 8). The FoundationModels adapter
/// maps SystemLanguageModel.Availability onto this, with `@unknown default` -> .unknown (R6/R7).
enum ModelAvailability: Equatable, Sendable {
    case available, deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, unknown
}

/// Why the app is in the no-model mode.
enum DeckReason: Equatable, Sendable {
    case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, suggestionsOff
}

enum FilingMode: Equatable, Sendable {
    case model
    case deck(DeckReason)

    /// Suggestions off wins over every availability. Otherwise .available -> .model;
    /// .unknown -> .deck(.deviceNotEligible) (PLAN section 8: unknown gets the
    /// deviceNotEligible copy); each other case -> .deck of the same-named reason.
    static func select(availability: ModelAvailability, suggestionsOn: Bool) -> FilingMode {
        guard suggestionsOn else { return .deck(.suggestionsOff) }
        switch availability {
        case .available: return .model
        case .unknown: return .deck(.deviceNotEligible)
        case .deviceNotEligible: return .deck(.deviceNotEligible)
        case .appleIntelligenceNotEnabled: return .deck(.appleIntelligenceNotEnabled)
        case .modelNotReady: return .deck(.modelNotReady)
        }
    }

    /// The FilingModel for this mode: `foundation()` for .model, DeckFilingModel() for .deck.
    /// `foundation` is not evaluated in deck mode.
    func filingModel(foundation: () -> any FilingModel) -> any FilingModel {
        switch self {
        case .model: return foundation()
        case .deck: return DeckFilingModel()
        }
    }
}

extension DeckReason {
    /// The banner copy for this reason, verbatim from AppCopy: deviceNotEligible -> newerPhoneReason,
    /// appleIntelligenceNotEnabled -> appleIntelligenceOffReason, modelNotReady -> modelsDownloadingReason,
    /// suggestionsOff -> nil (the user chose it; no banner).
    var copy: String? {
        switch self {
        case .deviceNotEligible: return AppCopy.newerPhoneReason
        case .appleIntelligenceNotEnabled: return AppCopy.appleIntelligenceOffReason
        case .modelNotReady: return AppCopy.modelsDownloadingReason
        case .suggestionsOff: return nil
        }
    }
}

/// The no-model FilingModel (PLAN section 5.3). No inference: every window yields an empty extract,
/// so the pipeline proposes nothing and assembles only the slotless follow-ups.
struct DeckFilingModel: FilingModel {
    func extract(from window: TranscriptWindow, periodTitles: [String]) async throws -> WindowExtract {
        WindowExtract()
    }
}
