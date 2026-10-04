import Foundation
import FoundationModels

// The only file that imports FoundationModels (R7 spec section 2; ModelBoundaryTests enforces it).
// It turns one transcript window into a WindowExtract and nothing else: no persistence type is
// named here, so nothing the model returns can reach the store except through SpanVerifier and
// the confirm flow.

// MARK: - The generable mirror of WindowExtract (PLAN section 6.2)

@Generable
fileprivate enum GeneratedReferentKind {
    case object, activity, moment, sensory
}

@Generable
fileprivate struct GeneratedReferent {
    @Guide(description: "The exact phrase, copied word for word.")
    var span: String

    @Guide(description: "What kind of thing it is.")
    var kind: GeneratedReferentKind
}

@Generable
fileprivate struct GeneratedExtract {
    @Guide(description: "The one entry from the supplied list of life periods that fits best, copied exactly, or nil if none fits.")
    var periodName: String?

    @Guide(description: "Exact phrases from the text, copied word for word, that name or describe a person, e.g. 'Dan' or 'my camp counselor'.", .maximumCount(8))
    var people: [String]

    @Guide(description: "Exact phrases from the text, copied word for word, that name a place.", .maximumCount(8))
    var places: [String]

    @Guide(description: "Exact phrases from the text, copied word for word, that say roughly when this was, e.g. 'the summer before eighth grade'. Empty if none.", .maximumCount(4))
    var timeCues: [String]

    @Guide(description: "Exact short phrases from the text, copied word for word, naming a thing, activity, or moment the speaker mentioned that could be asked about.", .maximumCount(8))
    var referents: [GeneratedReferent]

    @Guide(description: "One exact phrase of at most eight words, copied word for word from the text, that could serve as a title.")
    var titleSpan: String?
}

fileprivate func toExtract(_ g: GeneratedExtract) -> WindowExtract {
    WindowExtract(
        periodName: g.periodName,
        people: g.people,
        places: g.places,
        timeCues: g.timeCues,
        referents: g.referents.map { RawReferent(span: $0.span, kind: toKind($0.kind)) },
        titleSpan: g.titleSpan)
}

fileprivate func toKind(_ k: GeneratedReferentKind) -> ReferentKind {
    switch k {
    case .object: return .object
    case .activity: return .activity
    case .moment: return .moment
    case .sensory: return .sensory
    }
}

// MARK: - The model

/// The on-device FilingModel. A fresh session per window (PLAN section 6.2): no transcript
/// accumulates in any session's context. Every failure is a FilingModelError, so the pipeline
/// sends the capture to the no-model path instead of an alert.
struct FoundationFilingModel: FilingModel {
    var perWindowTimeout: Duration = .seconds(30)

    static let instructions = """
        You find exact phrases in a spoken transcript. Return only words that appear in the text, \
        copied word for word, in the order they appear. Never add, change, summarise or paraphrase \
        anything. If nothing fits a field, leave it empty. For the period, choose only from the list \
        given, copied exactly, or leave it empty.
        """

    /// "Periods: " + titles joined by " | ", a blank line, "Transcript:", then the window's FINAL
    /// segment texts joined by single spaces (the verifier matches only final segments).
    static func prompt(for window: TranscriptWindow, periodTitles: [String]) -> String {
        let text = window.segments.filter(\.isFinal).map(\.text).joined(separator: " ")
        return "Periods: " + periodTitles.joined(separator: " | ") + "\n\nTranscript:\n" + text
    }

    func extract(from window: TranscriptWindow, periodTitles: [String]) async throws -> WindowExtract {
        let prompt = Self.prompt(for: window, periodTitles: periodTitles)
        let timeout = perWindowTimeout
        do {
            return try await withThrowingTaskGroup(of: WindowExtract.self) { group in
                group.addTask { try await Self.respond(to: prompt) }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw FilingModelError.timeout
                }
                defer { group.cancelAll() }
                guard let first = try await group.next() else { throw FilingModelError.other }
                return first
            }
        } catch let error as FilingModelError {
            throw error
        } catch is CancellationError {
            throw FilingModelError.cancelled
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.map(error)
        } catch {
            throw FilingModelError.other
        }
    }

    private static func respond(to prompt: String) async throws -> WindowExtract {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedExtract.self,
            options: GenerationOptions(sampling: .greedy))
        return toExtract(response.content)
    }

    static func map(_ error: LanguageModelSession.GenerationError) -> FilingModelError {
        switch error {
        case .refusal, .guardrailViolation: return .refused
        case .assetsUnavailable: return .assetsNotReady
        case .unsupportedLanguageOrLocale: return .unsupportedLocale
        case .decodingFailure, .unsupportedGuide: return .decodingFailure
        case .exceededContextWindowSize: return .contextExceeded
        case .rateLimited, .concurrentRequests: return .rateLimited
        @unknown default: return .other
        }
    }
}

// MARK: - Availability (PLAN section 8)

extension ModelAvailability {
    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: self = .deviceNotEligible
            case .appleIntelligenceNotEnabled: self = .appleIntelligenceNotEnabled
            case .modelNotReady: self = .modelNotReady
            @unknown default: self = .unknown
            }
        @unknown default:
            self = .unknown
        }
    }

    /// The system model's availability right now. Read on each open of the confirm screen.
    static var current: ModelAvailability {
        ModelAvailability(SystemLanguageModel.default.availability)
    }
}

// MARK: - Token counter (R7 spec section 2.4)

/// Characters / 3, rounded up: a deliberate over-count (English runs about 4 characters a token),
/// because tokenCount(for:) is iOS 27 and the floor is iOS 26. Over-counting only makes windows
/// smaller. Dated deviation from PLAN section 6.3 item 1, 2026-10-04.
struct DeviceTokenCounter: TokenCounter {
    func count(_ text: String) -> Int {
        text.isEmpty ? 0 : max(1, (text.count + 2) / 3)
    }
}
