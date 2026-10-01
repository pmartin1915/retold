import Foundation

/// One authored question pattern. `{slot}` marks where a verified span goes. The full audited
/// deck and its lint are R3; R2 fixes the assembly mechanism and the six patterns of PLAN section 6.2.
struct QuestionTemplate: Equatable, Sendable {
    let id: String
    let cue: CueKind
    let pattern: String

    static let slotMarker = "{slot}"
    var slotCount: Int { pattern.components(separatedBy: Self.slotMarker).count - 1 }
}

enum FilingTemplates {
    static let when = QuestionTemplate(
        id: "when.open", cue: .event,
        pattern: "Roughly when was this \u{2014} a year, or how old you were?")
    static let whenWithCue = QuestionTemplate(
        id: "when.cue", cue: .event,
        pattern: "You said '{slot}' \u{2014} roughly what year would that be?")
    static let who = QuestionTemplate(
        id: "who.person", cue: .people,
        pattern: "Who was {slot} to you, back then?")
    static let sensoryPlace = QuestionTemplate(
        id: "sensory.place", cue: .sensory,
        pattern: "Anything about {slot} itself \u{2014} the light, the sounds, the weather? However small.")
    static let referent = QuestionTemplate(
        id: "referent.open", cue: .event,
        pattern: "You mentioned {slot}. Is there anything else about that?")
    static let broad = QuestionTemplate(
        id: "broad.open", cue: .event,
        pattern: "Anything else at all, however small?")
}

enum TemplateAssemblyError: Error, Equatable {
    case slotCountMismatch
    case slotsFromDifferentSegments
}

/// A question built by Swift from a template and verified spans. Not yet a persisted `Question`.
struct AssembledQuestion: Equatable, Sendable {
    let text: String
    let templateID: String
    let slots: [VerifiedSpan]
    let cue: CueKind

    /// The persisted form. `.deck` origin: every question the app shows comes from a template.
    func question(createdAt: Date = Date()) -> Question {
        Question(text: text, templateID: templateID, slots: slots, cue: cue, origin: .deck, createdAt: createdAt)
    }
}

enum TemplateAssembler {
    /// Fills `template` with exactly its number of verified spans. A template has one slot, or two
    /// only when both spans lie inside the same transcript segment (PLAN section 5.1 tail), so two
    /// true quotations from different moments are never juxtaposed. The check needs the
    /// segments; more than two slots is not allowed at all.
    static func assemble(
        _ template: QuestionTemplate,
        slots: [VerifiedSpan],
        segments: [TranscriptSegment] = []
    ) throws -> AssembledQuestion {
        guard slots.count == template.slotCount, template.slotCount <= 2 else {
            throw TemplateAssemblyError.slotCountMismatch
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
