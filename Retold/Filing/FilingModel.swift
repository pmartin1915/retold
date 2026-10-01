import Foundation

enum ReferentKind: String, Codable, Hashable, Sendable { case object, activity, moment, sensory }

struct RawReferent: Equatable, Sendable {
    var span: String
    var kind: ReferentKind
}

/// What one model call returns for one window (PLAN section 6.2, the `WindowExtract` shape).
/// Every String is a CLAIMED quotation: nothing here is trusted until `SpanVerifier` has
/// located it in the window. There is no free-text field.
struct WindowExtract: Equatable, Sendable {
    var periodName: String?
    var people: [String] = []
    var places: [String] = []
    var timeCues: [String] = []
    var referents: [RawReferent] = []
    var titleSpan: String?
}

/// Every way a model call can end without an extract (PLAN section 8). Each one sends the
/// capture to the no-model path; none is shown to the user as an error.
enum FilingModelError: Error, Equatable, Sendable {
    case refused, assetsNotReady, unsupportedLocale, decodingFailure
    case contextExceeded, rateLimited, timeout, cancelled
    case other
}

/// The seam between the pipeline and Apple's model. R2 ships only the mock; the
/// `FoundationModels` implementation arrives with the device-gated work and must make a FRESH
/// session per call (PLAN section 6.2).
protocol FilingModel: Sendable {
    func extract(from window: TranscriptWindow, periodTitles: [String]) async throws -> WindowExtract
}

/// Scripted model for tests and previews. The closure sees each call, so tests can count them
/// (through an actor) or fail the Nth.
struct MockFilingModel: FilingModel {
    let handler: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract

    func extract(from window: TranscriptWindow, periodTitles: [String]) async throws -> WindowExtract {
        try await handler(window, periodTitles)
    }
}
