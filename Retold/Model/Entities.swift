import Foundation
import SwiftData

// The seven entities of the R1 schema (docs/R1-DATAMODEL-SPEC.md section 3).
// Relationships are built from the owning side only; every relationship names its inverse
// on exactly one side, as written here. Person.episodes, Place.episodes and the `episode`
// back-references are deliberately bare properties with no @Relationship attribute.
//
// private(set) on stored properties is intentional: the only writers are the methods on
// this file's classes, which is what enforces the Rule-1 invariants.

@Model final class Period {
    var id: UUID
    var title: String                                   // user-owned text
    var approxStartAge: Confirmable<Int>?
    var approxEndAge: Confirmable<Int>?
    var sortOrder: Int
    @Relationship(deleteRule: .nullify, inverse: \Episode.period) var episodes: [Episode] = []
    var createdAt: Date

    init(title: String, sortOrder: Int, createdAt: Date = Date()) {
        id = UUID()
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model final class Episode {
    var id: UUID
    /// Rule 1 (PLAN 5.1 item 5): a title is a verified transcript span or typed by the user --
    /// never model text. The two initializers and three mutators below are its only writers.
    private(set) var title: Confirmable<String>
    var period: Period?
    private(set) var whenQuestionID: UUID?              // one of `questions`; question lives in `questions`
    private(set) var approxYear: Confirmable<Int>?
    private(set) var approxAge: Confirmable<Int>?
    @Relationship(inverse: \Place.episodes) var place: Place?
    @Relationship(inverse: \Person.episodes) var people: [Person] = []
    @Relationship(deleteRule: .cascade, inverse: \Capture.episode) var captures: [Capture] = []
    @Relationship(deleteRule: .cascade, inverse: \Detail.episode) var details: [Detail] = []
    @Relationship(deleteRule: .cascade, inverse: \Question.episode) var questions: [Question] = []
    private(set) var excerpt: String                    // verbatim first words of a transcript; "" until set
    var createdAt: Date

    /// Title proposed from a verified transcript span; its value is exactly `span.text`.
    init(titleQuote span: VerifiedSpan, createdAt: Date = Date()) {
        id = UUID()
        title = Confirmable.proposedQuote(span: span)
        excerpt = ""
        self.createdAt = createdAt
    }

    /// Title typed by the user.
    init(typedTitle: String, createdAt: Date = Date()) {
        id = UUID()
        title = Confirmable.userTyped(typedTitle)
        excerpt = ""
        self.createdAt = createdAt
    }

    /// The user taps the proposed title chip. False if it wasn't proposed.
    @discardableResult func confirmTitle() -> Bool { title.confirm() }
    /// The user declines the proposed title chip. False if it wasn't proposed.
    @discardableResult func rejectTitle() -> Bool { title.reject() }
    /// The user types their own title.
    func retitle(byUser text: String) { title.replaceByUser(text) }

    /// The ONLY writer of excerpt: the first 25 whitespace-separated words of the segments'
    /// texts, joined with single spaces, in order, unaltered (fewer if the transcript is shorter).
    func setExcerpt(from segments: [TranscriptSegment]) {
        let words = segments.flatMap { $0.text.split(whereSeparator: \.isWhitespace) }
        excerpt = words.prefix(25).map { String($0) }.joined(separator: " ")
    }

    var whenQuestion: Question? {
        guard let whenQuestionID else { return nil }
        return questions.first { $0.id == whenQuestionID }
    }

    /// Appends `question` to `questions` if not already there and sets whenQuestionID to its id.
    func setWhenQuestion(_ question: Question) {
        if !questions.contains(where: { $0.id == question.id }) {
            questions.append(question)
        }
        whenQuestionID = question.id
    }

    /// The ONLY writers of approxYear/approxAge (PLAN section 6.1: only ever set by the user
    /// answering whenQuestion). Sets the value as .userTyped and marks whenQuestion (if any) .answered.
    func answerWhen(year: Int) {
        approxYear = Confirmable.userTyped(year)
        whenQuestion?.status = .answered
    }

    func answerWhen(age: Int) {
        approxAge = Confirmable.userTyped(age)
        whenQuestion?.status = .answered
    }
}

@Model final class Detail {
    var id: UUID
    private(set) var text: String                        // fixed at init; a quote's text never changes
    var kind: DetailKind
    private(set) var provenance: StoredProvenance        // only .transcriptQuote or .userTyped; no mutator exists
    var episode: Episode?

    /// A verbatim transcript quote. There is no initializer from model output.
    init(quote span: VerifiedSpan, kind: DetailKind) {
        id = UUID()
        text = span.text
        self.kind = kind
        provenance = StoredProvenance(
            .transcriptQuote(captureID: span.captureID, start: span.start, end: span.end)
        )
    }

    /// A user-typed detail.
    init(typed text: String, kind: DetailKind) {
        id = UUID()
        self.text = text
        self.kind = kind
        provenance = StoredProvenance(.userTyped)
    }
}

@Model final class Person {
    var id: UUID
    var name: String
    var aliases: [String] = []
    var note: String?
    var episodes: [Episode] = []

    init(name: String) {
        id = UUID()
        self.name = name
    }
}

@Model final class Place {
    var id: UUID
    var name: String
    var episodes: [Episode] = []

    init(name: String) {
        id = UUID()
        self.name = name
    }
}

enum CaptureError: Error, Equatable {
    case transcriptAlreadyComplete
    case useCompleteTranscript
    case segmentIndexOutOfRange
}

@Model final class Capture {
    var id: UUID
    var audioFileName: String                            // relative to the app's audio directory
    var duration: TimeInterval
    private(set) var transcript: [TranscriptSegment] = []
    private(set) var transcriptionStatus: TranscriptionStatus
    private(set) var corrections: [UserCorrection] = []
    private(set) var rejectedProposals: [RejectedProposal] = []
    var answersQuestionID: UUID?
    var episode: Episode?
    var createdAt: Date

    init(audioFileName: String, duration: TimeInterval, createdAt: Date = Date()) {
        id = UUID()
        self.audioFileName = audioFileName
        self.duration = duration
        transcriptionStatus = .pending
        self.createdAt = createdAt
    }

    /// Transcriber-only writer. Throws .transcriptAlreadyComplete if the CURRENT status is
    /// .complete (checked first), and .useCompleteTranscript if the `status` ARGUMENT is
    /// .complete — completion goes only through completeTranscript.
    func updateTranscript(_ segments: [TranscriptSegment], status: TranscriptionStatus) throws {
        if transcriptionStatus == .complete { throw CaptureError.transcriptAlreadyComplete }
        if status == .complete { throw CaptureError.useCompleteTranscript }
        transcript = segments
        transcriptionStatus = status
    }

    /// Transcriber-only writer. Sets .complete; the transcript is frozen after.
    func completeTranscript(_ segments: [TranscriptSegment]) throws {
        if transcriptionStatus == .complete { throw CaptureError.transcriptAlreadyComplete }
        transcript = segments
        transcriptionStatus = .complete
    }

    /// User edit: appends a UserCorrection (originalText copied from the segment); transcript unchanged.
    func addCorrection(segmentIndex: Int, correctedText: String, at date: Date = Date()) throws {
        guard transcript.indices.contains(segmentIndex) else {
            throw CaptureError.segmentIndexOutOfRange
        }
        corrections.append(
            UserCorrection(
                id: UUID(),
                segmentIndex: segmentIndex,
                originalText: transcript[segmentIndex].text,
                correctedText: correctedText,
                createdAt: date
            )
        )
    }

    func logRejected(_ kind: ProposalKind, text: String, at date: Date = Date()) {
        rejectedProposals.append(RejectedProposal(kind: kind, text: text, rejectedAt: date))
    }
}

// text/templateID/slots/cue/origin are fixed at init: the audited deck assembler (R3/R4) is
// the only intended constructor, and nothing may relabel or rewrite a question afterwards.
@Model final class Question {
    var id: UUID
    private(set) var text: String                                    // assembled by Swift from templateID + slots (R3/R4)
    private(set) var templateID: String
    private(set) var slots: [VerifiedSpan] = []
    private(set) var cue: CueKind
    private(set) var origin: Origin                                  // .deck or .user only; init precondition
    var status: QuestionStatus
    var episode: Episode?
    var period: Period?                                 // one-way, no inverse
    var person: Person?                                 // one-way, no inverse
    var askedCount: Int
    var lastAskedAt: Date?
    var createdAt: Date

    init(
        text: String,
        templateID: String,
        slots: [VerifiedSpan],
        cue: CueKind,
        origin: Origin,
        createdAt: Date = Date()
    ) {
        precondition(origin != .model)                  // no question is ever model text
        id = UUID()
        self.text = text
        self.templateID = templateID
        self.slots = slots
        self.cue = cue
        self.origin = origin
        status = .open
        askedCount = 0
        self.createdAt = createdAt
    }
}
