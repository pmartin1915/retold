import Foundation

/// A value snapshot of a persisted `Question`, for the engine's pure functions (R4
/// takes its inputs as values; nothing here touches a ModelContext).
struct AskRecord: Equatable, Sendable {
    let questionID: UUID
    let templateID: String
    let cue: CueKind
    /// phraseKey of slots[0].text; "" when slotless.
    let slotKey: String
    let status: QuestionStatus
    let lastAskedAt: Date?
}

extension AskRecord {
    @MainActor
    init(_ question: Question) {
        self.init(
            questionID: question.id,
            templateID: question.templateID,
            cue: question.cue,
            slotKey: question.slots.first.map { SpanVerifier.phraseKey($0.text) } ?? "",
            status: question.status,
            lastAskedAt: question.lastAskedAt
        )
    }
}

/// Everything the engine needs to know about one episode.
struct EpisodeState: Equatable, Sendable {
    var latestCaptureAt: Date? = nil
    var transcriptTexts: [String] = []
    var referentSpans: [VerifiedSpan] = []
    var placeSpans: [VerifiedSpan] = []
    var asks: [AskRecord] = []
}

extension EpisodeState {
    @MainActor
    init(episode: Episode) {
        let questions = episode.questions
        // An answer to the broad opener must not re-arm it (PLAN section 7).
        let broadIDs = Set(questions.filter { $0.templateID == "broad.open" }.map(\.id))
        let capturing = episode.captures.filter { capture in
            guard let answeredID = capture.answersQuestionID else { return true }
            return !broadIDs.contains(answeredID)
        }
        latestCaptureAt = capturing.map(\.createdAt).max()

        var texts: [String] = []
        for capture in episode.captures.sorted(by: { $0.createdAt < $1.createdAt }) {
            for segment in capture.transcript { texts.append(segment.text) }
            for correction in capture.corrections { texts.append(correction.correctedText) }
        }
        transcriptTexts = texts

        // Relationship arrays are unordered: sort, then deduplicate by phrase key (first wins).
        // A span inside a segment the user has since corrected is stale (Sol R2 audit 5).
        let captures = episode.captures
        referentSpans = slotSpans(of: questions, templateIDs: ["referent.open", "sensory.mentioned"], captures: captures)
        placeSpans = slotSpans(of: questions, templateIDs: ["sensory.place"], captures: captures)
        asks = questions.map { AskRecord($0) }
    }
}

/// Everything the engine needs to know about one person (PLAN section 7: person
/// questions only for a person the user named unprompted).
struct PersonState: Equatable, Sendable {
    /// Unprompted spans only (see the adapter).
    var spans: [VerifiedSpan] = []
    var episodeCount: Int = 0
    var asks: [AskRecord] = []
}

extension PersonState {
    @MainActor
    init(person: Person) {
        var seenIDs = Set<UUID>()
        var allQuestions: [Question] = []
        var captures: [Capture] = []
        for episode in person.episodes {
            for question in episode.questions where seenIDs.insert(question.id).inserted {
                allQuestions.append(question)
            }
            captures.append(contentsOf: episode.captures)
        }
        let mine = allQuestions.filter { $0.person?.id == person.id }
        asks = mine.map { AskRecord($0) }
        episodeCount = person.episodes.count

        var seenKeys = Set<String>()
        var out: [VerifiedSpan] = []
        let sorted = mine
            .filter { Self.personTemplateIDs.contains($0.templateID) && !$0.slots.isEmpty }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        for question in sorted {
            let span = question.slots[0]
            // Fail closed: a span whose capture is missing, or whose capture answers a
            // question that cannot be resolved there (e.g. a period. question, which has
            // no episode), is dropped. Filter before deduplicating, so a dropped span does
            // not hide a valid one with the same key.
            guard isUnpromptedSpan(span, captures: captures, questions: allQuestions),
                  !isCorrected(span, captures: captures)
            else { continue }
            guard seenKeys.insert(SpanVerifier.phraseKey(span.text)).inserted else { continue }
            out.append(span)
        }
        spans = out
    }

    private static let personTemplateIDs: Set<String> =
        ["who.person", "people.describe", "people.talk", "people.together"]
}

/// Everything the engine needs to know about one period. `Question.period` has no
/// inverse, so the caller passes candidate questions.
struct PeriodState: Equatable, Sendable {
    var episodeCount: Int = 0
    var asks: [AskRecord] = []
    /// The period's title as a fill; nil only in tests that do not need the opener.
    var titleFill: PeriodTitleFill? = nil
}

extension PeriodState {
    @MainActor
    init(period: Period, questions: [Question]) {
        asks = questions
            .filter { $0.period?.id == period.id }
            .map { AskRecord($0) }
        episodeCount = period.episodes.count
        titleFill = period.titleFill
    }
}

/// A queued question: either a persisted one to show again, or a new assembled one to
/// persist (`question.question()`).
struct EngineOffer: Equatable, Sendable {
    let question: AssembledQuestion
    /// Non-nil: show this persisted Question; nil: persist question.question().
    let existingQuestionID: UUID?

    var channel: QuestionChannel { QuestionChannel.of(templateID: question.templateID, cue: question.cue) }
}

enum QuestionEngine {
    static let episodeTemplateIDs = ["referent.open", "event.else", "event.shape", "event.anyone",
        "sensory.mentioned", "sensory.place", "sensory.everything", "sequence.connect", "sequence.otherTimes"]
    static let personTemplateIDs = ["who.person", "people.describe", "people.talk", "people.together"]
    static let periodTemplateIDs = ["period.else", "period.who", "period.where"]

    static var episodeTemplates: [QuestionTemplate] {
        episodeTemplateIDs.compactMap { QuestionDeck.template(id: $0) }
    }
    static var personTemplates: [QuestionTemplate] {
        personTemplateIDs.compactMap { QuestionDeck.template(id: $0) }
    }
    static var periodTemplates: [QuestionTemplate] {
        periodTemplateIDs.compactMap { QuestionDeck.template(id: $0) }
    }

    /// Templates the engine never offers (R5 owns period.slot and the theme.* cards; the
    /// when question belongs to the confirm flow), and asks that never count as negatives
    /// or as the user-initiated detail behind the sequence gate. period.slot is excluded
    /// from negatives on purpose: a retired opener was asked about an EMPTY period, so it
    /// must not silence the period cues that come once the period has episodes.
    private static let excludedTemplateIDs: Set<String> = ["broad.open", "when.open", "when.cue", "period.slot"]

    // MARK: - Episode queue

    static func queue(for state: EpisodeState, templates: [QuestionTemplate] = episodeTemplates) -> [EngineOffer] {
        guard let latestCaptureAt = state.latestCaptureAt else { return [] }
        var offers: [EngineOffer] = []

        // Broad opener: pending until a broad.open ask was shown since the latest capture.
        // Other questions shown since (e.g. the when question) do not consume it.
        let broadPending = !state.asks.contains {
            $0.templateID == "broad.open" && ($0.lastAskedAt ?? .distantPast) > latestCaptureAt
        }
        if broadPending {
            let existingID = state.asks.first {
                $0.templateID == "broad.open" && $0.status == .open && $0.lastAskedAt == nil
            }?.questionID
            if let broad = broadOffer(existingID: existingID) {
                offers.append(broad)
            }
        }

        let mentioned = SensoryChannel.mentioned(in: state.transcriptTexts)
        let mostRecent = mostRecentAsk(state.asks)
        let negatives = state.asks.filter {
            $0.status == .retired && !excludedTemplateIDs.contains($0.templateID)
        }
        // Sequence cues only after a user-initiated detail beyond the first telling
        // (answering the when wheel is not one).
        let sequenceGateOpen = state.asks.contains {
            $0.status == .answered && ($0.cue == .event || $0.cue == .sensory)
                && !excludedTemplateIDs.contains($0.templateID)
        }

        var candidates: [EpisodeCandidate] = []
        for (ti, template) in templates.enumerated() {
            if excludedTemplateIDs.contains(template.id) || template.cue == .period || template.cue == .people {
                continue
            }
            guard template.cue != .sequence || sequenceGateOpen else { continue }
            guard LeadingQuestionLint.violations(in: template.pattern, mentionedChannels: mentioned).isEmpty else {
                continue
            }
            let options = slotOptions(for: template, state: state)
            for (si, option) in options.enumerated() {
                let slotKey = option.span.map { SpanVerifier.phraseKey($0.text) } ?? ""
                let existing = state.asks.first {
                    $0.templateID == template.id && $0.slotKey == slotKey
                }
                if let existing, existing.status == .answered || existing.status == .retired { continue }
                if negatives.contains(where: { $0.cue == template.cue && $0.slotKey == slotKey }) { continue }
                let slots = option.span.map { [$0] } ?? []
                guard let question = try? TemplateAssembler.assemble(template, slots: slots) else { continue }
                let level: Int
                switch template.cue {
                case .event: level = 0
                case .sensory: level = 1
                case .sequence: level = 2
                case .period, .people: continue
                }
                candidates.append(EpisodeCandidate(
                    skipped: existing?.status == .skipped,
                    level: level,
                    sameSlot: !slotKey.isEmpty && slotKey == mostRecent?.slotKey,
                    slotless: option.span == nil,
                    ti: ti,
                    si: si,
                    offer: EngineOffer(question: question, existingQuestionID: existing?.questionID)
                ))
            }
        }
        // Bool is not Comparable, so the flags sort as 0/1.
        candidates.sort {
            ($0.skipped.rank, $0.level, $0.sameSlot.rank, $0.slotless.rank, $0.ti, $0.si)
                < ($1.skipped.rank, $1.level, $1.sameSlot.rank, $1.slotless.rank, $1.ti, $1.si)
        }
        offers.append(contentsOf: candidates.map(\.offer))
        return offers
    }

    static func next(
        for state: EpisodeState,
        recentChannels: [QuestionChannel],
        templates: [QuestionTemplate] = episodeTemplates
    ) -> EngineOffer? {
        for offer in queue(for: state, templates: templates) {
            // The pending broad opener is exempt from the cap.
            if offer.question.templateID == "broad.open" { return offer }
            if !isBlocked(offer.channel, recentChannels: recentChannels) { return offer }
        }
        return nil
    }

    // MARK: - Person queue

    static func queue(for state: PersonState) -> [EngineOffer] {
        guard !state.spans.isEmpty,
              state.asks.filter({ $0.status == .answered }).count < state.episodeCount
        else { return [] }
        return queue(templates: personTemplates, slot: state.spans[0], asks: state.asks)
    }

    static func next(for state: PersonState, recentChannels: [QuestionChannel]) -> EngineOffer? {
        queue(for: state).first { !isBlocked($0.channel, recentChannels: recentChannels) }
    }

    // MARK: - Period queue

    static func queue(for state: PeriodState) -> [EngineOffer] {
        guard state.episodeCount == 0 else {
            return queue(templates: periodTemplates, slot: nil, asks: state.asks)
        }
        // The empty-period opener (R5): one question on the period's own title, so a
        // no-model user has a way into a seeded period. See docs/R5-DECK-EXPORT-SPEC.md
        // section 2.2 for the recorded departure from PLAN section 7's gate.
        guard let fill = state.titleFill else { return [] }
        let existing = state.asks.first { $0.templateID == "period.slot" }
        if let existing, existing.status == .answered || existing.status == .retired { return [] }
        // The opener stands down when the user has already retired a period-cue question
        // about this empty period (the shared negatives rule, period.slot itself excluded).
        let negatives = state.asks.filter {
            $0.status == .retired && !excludedTemplateIDs.contains($0.templateID)
        }
        if negatives.contains(where: { $0.cue == .period && $0.slotKey == "" }) { return [] }
        guard let template = QuestionDeck.template(id: "period.slot"),
              let question = try? TemplateAssembler.assemble(template, periodTitle: fill)
        else { return [] }
        return [EngineOffer(question: question, existingQuestionID: existing?.questionID)]
    }

    static func next(for state: PeriodState, recentChannels: [QuestionChannel]) -> EngineOffer? {
        queue(for: state).first { !isBlocked($0.channel, recentChannels: recentChannels) }
    }

    // MARK: - Theme card queue

    /// The card's templates through the shared loop, slot nil, sorted (skipped, ti). No gate: a
    /// theme card is a way in for any user, including one with an empty library.
    static func queue(for card: ThemeCard, state: ThemeState) -> [EngineOffer] {
        let templates = card.templateIDs.compactMap { QuestionDeck.template(id: $0) }
        return queue(templates: templates, slot: nil, asks: state.asks)
    }

    static func next(for card: ThemeCard, state: ThemeState, recentChannels: [QuestionChannel]) -> EngineOffer? {
        queue(for: card, state: state).first { !isBlocked($0.channel, recentChannels: recentChannels) }
    }

    /// The shared person/period candidate loop: one slotless option (period) or one
    /// option on `slot` (person), same exclusion, negative and existing-id rules as the
    /// episode queue. Sorted `(skipped, ti)`.
    private static func queue(
        templates: [QuestionTemplate],
        slot: VerifiedSpan?,
        asks: [AskRecord]
    ) -> [EngineOffer] {
        let slotKey = slot.map { SpanVerifier.phraseKey($0.text) } ?? ""
        let negatives = asks.filter {
            $0.status == .retired && !excludedTemplateIDs.contains($0.templateID)
        }
        var candidates: [(skipped: Bool, ti: Int, offer: EngineOffer)] = []
        for (ti, template) in templates.enumerated() {
            let existing = asks.first { $0.templateID == template.id && $0.slotKey == slotKey }
            if let existing, existing.status == .answered || existing.status == .retired { continue }
            if negatives.contains(where: { $0.cue == template.cue && $0.slotKey == slotKey }) { continue }
            let slots = slot.map { [$0] } ?? []
            guard let question = try? TemplateAssembler.assemble(template, slots: slots) else { continue }
            candidates.append((existing?.status == .skipped, ti,
                EngineOffer(question: question, existingQuestionID: existing?.questionID)))
        }
        candidates.sort { ($0.skipped.rank, $0.ti) < ($1.skipped.rank, $1.ti) }
        return candidates.map(\.offer)
    }

    // MARK: - App-wide channel history

    /// The channels of the last two questions shown anywhere, oldest first: questions with
    /// a lastAskedAt, broad.open excluded, sorted by lastAskedAt. App-wide on purpose:
    /// "in a row" is what the user experiences, across pages.
    @MainActor
    static func recentChannels(from questions: [Question]) -> [QuestionChannel] {
        let shown = questions
            .filter { $0.lastAskedAt != nil && $0.templateID != "broad.open" }
            .sorted { a, b in
                if let da = a.lastAskedAt, let db = b.lastAskedAt, da != db { return da < db }
                return a.id.uuidString < b.id.uuidString
            }
        return shown.suffix(2).map { QuestionChannel.of(templateID: $0.templateID, cue: $0.cue) }
    }

    // MARK: - Private helpers

    private struct SlotOption {
        let span: VerifiedSpan?
    }

    private struct EpisodeCandidate {
        let skipped: Bool
        let level: Int
        let sameSlot: Bool
        let slotless: Bool
        let ti: Int
        let si: Int
        let offer: EngineOffer
    }

    private static func broadOffer(existingID: UUID?) -> EngineOffer? {
        guard let question = try? TemplateAssembler.assemble(FilingTemplates.broad, slots: []) else {
            return nil
        }
        return EngineOffer(question: question, existingQuestionID: existingID)
    }

    /// A channel is blocked when it is the last two shown.
    private static func isBlocked(_ channel: QuestionChannel, recentChannels: [QuestionChannel]) -> Bool {
        recentChannels.count >= 2 && recentChannels.suffix(2).allSatisfy { $0 == channel }
    }

    /// The slot options for one episode template: one slotless option, the shared
    /// referent spans (each span goes to exactly one of referent.open /
    /// sensory.mentioned), the place spans, or none.
    private static func slotOptions(for template: QuestionTemplate, state: EpisodeState) -> [SlotOption] {
        if template.slotCount == 0 { return [SlotOption(span: nil)] }
        guard template.slotCount == 1 else { return [] }
        switch template.id {
        case "referent.open", "sensory.mentioned":
            return state.referentSpans
                .filter { referentTemplateID(for: $0, asks: state.asks) == template.id }
                .map { SlotOption(span: $0) }
        case "sensory.place":
            return state.placeSpans.map { SlotOption(span: $0) }
        default:
            return []
        }
    }

    /// Each referent span goes to exactly one of referent.open / sensory.mentioned (they
    /// would be paraphrases): an existing ask under either id wins (R2's filed
    /// referent.open question is reused, never orphaned); otherwise sensory.mentioned
    /// when the span itself mentions a channel, else referent.open.
    private static func referentTemplateID(for span: VerifiedSpan, asks: [AskRecord]) -> String {
        let key = SpanVerifier.phraseKey(span.text)
        let askedIDs = Set(asks.filter {
            ($0.templateID == "referent.open" || $0.templateID == "sensory.mentioned")
                && $0.slotKey == key
        }.map(\.templateID))
        if askedIDs.contains("referent.open") { return "referent.open" }
        if askedIDs.contains("sensory.mentioned") { return "sensory.mentioned" }
        return SensoryChannel.mentioned(in: [span.text]).isEmpty ? "referent.open" : "sensory.mentioned"
    }

    /// The most recent ask (non-nil lastAskedAt, broad.open excluded); ties by
    /// questionID.uuidString descending.
    private static func mostRecentAsk(_ asks: [AskRecord]) -> AskRecord? {
        let shown = asks.filter { $0.templateID != "broad.open" && $0.lastAskedAt != nil }
        guard let latest = shown.compactMap(\.lastAskedAt).max() else { return nil }
        return shown
            .filter { $0.lastAskedAt == latest }
            .sorted { $0.questionID.uuidString > $1.questionID.uuidString }
            .first
    }
}

/// slots[0] of `questions` whose templateID is in `templateIDs`, sorted by
/// (createdAt, id.uuidString), deduplicated by phrase key (first wins).
@MainActor
private func slotSpans(of questions: [Question], templateIDs: Set<String>, captures: [Capture]) -> [VerifiedSpan] {
    var seen = Set<String>()
    var out: [VerifiedSpan] = []
    let sorted = questions
        .filter { templateIDs.contains($0.templateID) && !$0.slots.isEmpty }
        .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    for question in sorted {
        let span = question.slots[0]
        // Stale spans are dropped before deduplication, so a fresh duplicate still counts.
        guard !isCorrected(span, captures: captures) else { continue }
        if seen.insert(SpanVerifier.phraseKey(span.text)).inserted {
            out.append(span)
        }
    }
    return out
}

/// True when the span's capture has a correction on a segment that contains the span: it
/// quotes words the user has since corrected, so no question may be built on it again.
@MainActor
private func isCorrected(_ span: VerifiedSpan, captures: [Capture]) -> Bool {
    guard let capture = captures.first(where: { $0.id == span.captureID }) else { return false }
    return capture.corrections.contains { correction in
        guard capture.transcript.indices.contains(correction.segmentIndex) else { return false }
        let segment = capture.transcript[correction.segmentIndex]
        return segment.start <= span.start && span.end <= segment.end
    }
}

private extension Bool {
    var rank: Int { self ? 1 : 0 }
}

/// People cues only for a person the user named unprompted (PLAN section 7): the span's
/// capture answers no question, or a question found among the person's episodes'
/// questions that is not on the people channel. Fail closed on anything unresolved.
@MainActor
private func isUnpromptedSpan(_ span: VerifiedSpan, captures: [Capture], questions: [Question]) -> Bool {
    guard let capture = captures.first(where: { $0.id == span.captureID }) else { return false }
    guard let answeredID = capture.answersQuestionID else { return true }
    guard let answered = questions.first(where: { $0.id == answeredID }) else { return false }
    return QuestionChannel.of(templateID: answered.templateID, cue: answered.cue) != .people
}
