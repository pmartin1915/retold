import Foundation

enum TemplateAssemblyError: Error, Equatable {
    case slotCountMismatch
    case slotsFromDifferentSegments
    /// Every word of a slot was a function word (e.g. "I"), which would fill a who
    /// question with nothing to remember (PLAN section 6.2 follow-ups, R3 fix).
    case slotIsFunctionWord
    /// assemble(_:periodTitle:) was given a template other than period.slot.
    case notAPeriodTitleTemplate
    /// The fill had no word left after trimming whitespace.
    case emptySlot
}

/// A user-owned Period.title as a slot fill (R5, the one non-span fill). Only Period.titleFill
/// below builds one; the fill is sealed like the verified-span path it parallels.
struct PeriodTitleFill: Equatable, Sendable {
    let text: String

    fileprivate init(text: String) { self.text = text }

    #if DEBUG
    static func fixture(_ text: String) -> PeriodTitleFill { PeriodTitleFill(text: text) }
    #endif
}

extension Period {
    /// The period's current title as a slot fill.
    var titleFill: PeriodTitleFill { PeriodTitleFill(text: title) }
}

/// A question built by Swift from a template and verified spans. Not yet a persisted `Question`.
struct AssembledQuestion: Equatable, Sendable {
    let text: String
    let templateID: String
    let slots: [VerifiedSpan]
    let cue: CueKind

    /// Only TemplateAssembler.assemble builds one (R4.5, Sol R2 finding 2).
    fileprivate init(text: String, templateID: String, slots: [VerifiedSpan], cue: CueKind) {
        self.text = text
        self.templateID = templateID
        self.slots = slots
        self.cue = cue
    }

    /// The persisted form. `.deck` origin: every question the app shows comes from a template.
    func question(createdAt: Date = Date()) -> Question {
        Question(assembled: self, createdAt: createdAt)
    }
}

enum TemplateAssembler {
    /// Words that may not fill a slot alone; a span made only of these says nothing
    /// a question could hang on (R3 function-word guard).
    private static let functionWords: Set<String> = [
        "i", "me", "my", "mine", "myself", "you", "your", "yours",
        "he", "him", "his", "she", "her", "hers", "it", "its",
        "we", "us", "our", "ours", "they", "them", "their", "theirs",
        "this", "that", "these", "those", "there", "here",
        "a", "an", "the", "and", "or", "but", "so", "then", "um", "uh", "like", "just",
    ]

    /// Fills `template` with exactly its number of verified spans. A template has one slot, or two
    /// only when both spans lie inside the same transcript segment (PLAN section 5.1 tail), so two
    /// true quotations from different moments are never juxtaposed. The check needs the
    /// segments; more than two slots is not allowed at all. A slot whose every word is a
    /// function word (e.g. "I") is rejected too: it is verbatim, but it fills the who
    /// question with nothing to remember.
    static func assemble(
        _ template: QuestionTemplate,
        slots: [VerifiedSpan],
        segments: [TranscriptSegment] = []
    ) throws -> AssembledQuestion {
        guard slots.count == template.slotCount, template.slotCount <= 2 else {
            throw TemplateAssemblyError.slotCountMismatch
        }
        for slot in slots {
            try checkSlotText(slot.text)
        }
        if slots.count == 2 {
            let sameSegment = segments.contains { segment in
                slots.allSatisfy { $0.start >= segment.start && $0.end <= segment.end }
            }
            guard sameSegment else { throw TemplateAssemblyError.slotsFromDifferentSegments }
        }
        // Split on the pattern's own markers and interleave the spans, so a span whose text
        // happens to contain "{slot}" can never be re-expanded.
        let pieces = template.pattern.components(separatedBy: QuestionTemplate.slotMarker)
        var text = pieces[0]
        for (index, span) in slots.enumerated() {
            text += span.text + pieces[index + 1]
        }
        return AssembledQuestion(text: text, templateID: template.id, slots: slots, cue: template.cue)
    }

    /// Fills period.slot with a period title — the one non-span fill (R5; the sealed
    /// PeriodTitleFill is why only a user-owned title can take this path). Throws
    /// .notAPeriodTitleTemplate unless template.id == "period.slot" AND template.slotCount == 1
    /// (both checked before any indexing); .emptySlot if the title is empty after trimming
    /// whitespace and newlines; .slotIsFunctionWord under the same function-word rule as span
    /// slots. Otherwise the text is the pattern with its single {slot} replaced by the
    /// normalised title: each run of newlines becomes one space, then leading/trailing
    /// whitespace is trimmed. Built by the same split-and-interleave as
    /// assemble(_:slots:segments:), so a title containing "{slot}" is never re-expanded. The
    /// result has slots == [] (no transcript span is involved) and cue .period.
    static func assemble(_ template: QuestionTemplate, periodTitle fill: PeriodTitleFill) throws -> AssembledQuestion {
        guard template.id == "period.slot", template.slotCount == 1 else {
            throw TemplateAssemblyError.notAPeriodTitleTemplate
        }
        let normalised = fill.text
            .split(whereSeparator: { $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !normalised.isEmpty else { throw TemplateAssemblyError.emptySlot }
        try checkSlotText(normalised)
        let pieces = template.pattern.components(separatedBy: QuestionTemplate.slotMarker)
        let text = pieces[0] + normalised + pieces[1]
        return AssembledQuestion(text: text, templateID: template.id, slots: [], cue: template.cue)
    }

    /// The function-word guard shared by both assemble entry points: a fill whose every
    /// word is a function word (e.g. "That") says nothing a question could hang on.
    private static func checkSlotText(_ text: String) throws {
        let keys = text.split(whereSeparator: \.isWhitespace)
            .map({ SpanVerifier.key(String($0)) })
            .filter({ !$0.isEmpty })
        if !keys.isEmpty && keys.allSatisfy({ functionWords.contains($0) }) {
            throw TemplateAssemblyError.slotIsFunctionWord
        }
    }

    /// The follow-up questions for a merged extract, in offer order: the open question first
    /// (broad before narrow, PLAN section 7), then the when question (with the time cue if one was
    /// verified), then up to `maxFollowUps` more, rotating referent -> place -> person so no
    /// one kind is drilled while the others wait. Never throws: every template used here has
    /// exactly the slots supplied.
    static func followUps(from merged: MergedExtract, maxFollowUps: Int = 5) -> [AssembledQuestion] {
        var out: [AssembledQuestion] = []
        func add(_ template: QuestionTemplate, _ slots: [VerifiedSpan] = []) {
            if let question = try? assemble(template, slots: slots) { out.append(question) }
        }

        add(FilingTemplates.broad)
        if let cue = merged.timeCues.first {
            add(FilingTemplates.whenWithCue, [cue])
        } else {
            add(FilingTemplates.when)
        }

        var referents = merged.referents.map(\.span)[...]
        var places = merged.places[...]
        var people = merged.people[...]
        var added = 0
        while added < maxFollowUps, !(referents.isEmpty && places.isEmpty && people.isEmpty) {
            if added < maxFollowUps, let next = referents.popFirst() {
                add(FilingTemplates.referent, [next]); added += 1
            }
            if added < maxFollowUps, let next = places.popFirst() {
                add(FilingTemplates.sensoryPlace, [next]); added += 1
            }
            if added < maxFollowUps, let next = people.popFirst() {
                add(FilingTemplates.who, [next]); added += 1
            }
        }
        return out
    }
}
