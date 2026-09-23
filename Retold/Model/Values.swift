import Foundation

// Value types shared by the data model. None of these is a SwiftData entity;
// they are persisted as composite attributes of the @Model classes.

enum Origin: String, Codable, Hashable, Sendable { case model, deck, user }
enum ConfirmStatus: String, Codable, Hashable, Sendable { case proposed, confirmed, rejected }
enum DetailKind: String, Codable, Hashable, Sendable { case sensory, people, sequence, emotion, object }
enum CueKind: String, Codable, Hashable, Sendable { case period, event, sensory, people, sequence }
enum QuestionStatus: String, Codable, Hashable, Sendable { case open, answered, skipped, retired }
enum TranscriptionStatus: String, Codable, Hashable, Sendable { case pending, live, fromFile, complete, failed }
enum ProposalKind: String, Codable, Hashable, Sendable { case title, period, person, place, timeCue, referent }

/// An exact transcript quotation with its audio range. R2's verifier is the only producer in
/// production; R1 constructs them directly in tests.
struct VerifiedSpan: Codable, Hashable, Sendable {
    let text: String
    let captureID: UUID
    let start: TimeInterval
    let end: TimeInterval

    /// Never traps, even on a decoded value whose start > end.
    var range: ClosedRange<TimeInterval> { min(start, end)...max(start, end) }

    init(text: String, captureID: UUID, start: TimeInterval, end: TimeInterval) {
        precondition(start <= end)
        self.text = text
        self.captureID = captureID
        self.start = start
        self.end = end
    }
}

struct TranscriptSegment: Codable, Hashable, Sendable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    var isFinal: Bool
}

/// A user's edit to one transcript segment. The transcript itself is never rewritten.
struct UserCorrection: Codable, Hashable, Sendable {
    let id: UUID
    let segmentIndex: Int
    let originalText: String      // copied from the segment at correction time
    let correctedText: String
    let createdAt: Date
}

/// A chip the user declined in the confirm flow (PLAN section 6.2 step 3), kept for tests and audit.
struct RejectedProposal: Codable, Hashable, Sendable {
    let kind: ProposalKind
    let text: String
    let rejectedAt: Date
}
