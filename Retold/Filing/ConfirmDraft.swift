import Foundation

/// A snapshot of an existing Person or Place, so the draft never holds a model entity.
struct EntityRef: Equatable, Sendable {
    let id: UUID
    let name: String
}

/// A snapshot of an existing Period.
struct PeriodRef: Equatable, Sendable {
    let id: UUID
    let title: String
    let sortOrder: Int
}

enum ChipState: Equatable, Sendable {
    case suggested, accepted, rejected
}

struct SpanChip: Equatable, Sendable, Identifiable {
    let id: UUID
    let span: VerifiedSpan
    var state: ChipState = .suggested
    let match: EntityRef?
    var useMatch: Bool = true
}

enum PeriodPick: Equatable, Sendable {
    case none
    case existing(UUID)
    case new(String)
}

enum WhenAnswer: Equatable, Sendable {
    case notSure
    case year(Int)
    case age(Int)
}

enum TypedEntity: Equatable, Sendable {
    case existing(UUID)
    case new(String)
}

enum RowChoice: Equatable, Sendable {
    case later, notThisOne
}

struct FollowUpRow: Equatable, Sendable, Identifiable {
    let id: UUID
    let question: AssembledQuestion
    var choice: RowChoice = .later
}

enum ResolvedTitle: Equatable, Sendable {
    case typed(String)
    case quote(VerifiedSpan)
}

enum UnfiledRow: Equatable, Sendable {
    case transcribing
    case ready(excerpt: String)
    case noTranscript
}

struct ConfirmDraft: Equatable, Sendable {
    let captureID: UUID
    var titleChip: SpanChip?
    var typedTitle: String = ""
    let suggestedPeriod: PeriodRef?
    var periodSuggestionState: ChipState = .suggested
    var periodPick: PeriodPick = .none
    let whenQuestion: AssembledQuestion
    var when: WhenAnswer = .notSure
    var people: [SpanChip]
    var typedPeople: [TypedEntity] = []
    var places: [SpanChip]
    var typedPlace: TypedEntity?
    var followUps: [FollowUpRow]
    let knownPeople: [EntityRef]
    let knownPlaces: [EntityRef]
}

extension ConfirmDraft {
    static func make(
        captureID: UUID,
        outcome: FilingOutcome?,
        periods: [PeriodRef],
        people: [EntityRef],
        places: [EntityRef],
        makeID: () -> UUID = UUID.init
    ) -> ConfirmDraft {
        let merged: MergedExtract
        let questions: [AssembledQuestion]
        switch outcome {
        case .some(.proposal(let proposed, let assembled)):
            merged = proposed
            questions = assembled
        case .some(.noModel), .none:
            merged = MergedExtract()
            questions = TemplateAssembler.followUps(from: merged)
        }

        func match(for span: VerifiedSpan, in entities: [EntityRef]) -> EntityRef? {
            let key = SpanVerifier.phraseKey(span.text)
            return entities.first { SpanVerifier.phraseKey($0.name) == key }
        }

        let titleChip = merged.titleSpan.map {
            SpanChip(id: makeID(), span: $0, match: nil)
        }
        let personChips = merged.people.compactMap { span -> SpanChip? in
            guard (try? TemplateAssembler.assemble(FilingTemplates.who, slots: [span])) != nil else {
                return nil
            }
            return SpanChip(id: makeID(), span: span, match: match(for: span, in: people))
        }
        let placeChips = merged.places.compactMap { span -> SpanChip? in
            guard (try? TemplateAssembler.assemble(FilingTemplates.sensoryPlace, slots: [span])) != nil else {
                return nil
            }
            return SpanChip(id: makeID(), span: span, match: match(for: span, in: places))
        }

        let whenIndex = questions.firstIndex {
            $0.templateID == FilingTemplates.when.id ||
                $0.templateID == FilingTemplates.whenWithCue.id
        }
        let fallbackWhen = TemplateAssembler.followUps(from: MergedExtract()).first {
            $0.templateID == FilingTemplates.when.id
        }!
        let whenQuestion = whenIndex.map { questions[$0] } ?? fallbackWhen
        let followUps = questions.enumerated().compactMap { index, question in
            if let whenIndex, index == whenIndex { return nil }
            return FollowUpRow(id: makeID(), question: question)
        }
        let suggestedPeriod = merged.periodTitle.flatMap { suggestedTitle in
            periods.first { $0.title == suggestedTitle }
        }

        return ConfirmDraft(
            captureID: captureID,
            titleChip: titleChip,
            suggestedPeriod: suggestedPeriod,
            whenQuestion: whenQuestion,
            people: personChips,
            places: placeChips,
            followUps: followUps,
            knownPeople: people,
            knownPlaces: places
        )
    }

    mutating func acceptTitle() {
        titleChip?.state = .accepted
    }

    mutating func rejectTitle() {
        titleChip?.state = .rejected
    }

    mutating func acceptSuggestedPeriod() {
        guard let suggestedPeriod else { return }
        periodSuggestionState = .accepted
        periodPick = .existing(suggestedPeriod.id)
    }

    mutating func rejectSuggestedPeriod() {
        guard let suggestedPeriod else { return }
        periodSuggestionState = .rejected
        if case .existing(let id) = periodPick, id == suggestedPeriod.id {
            periodPick = .none
        }
    }

    mutating func pick(_ pick: PeriodPick) {
        if case .existing(let id) = pick, id == suggestedPeriod?.id {
            acceptSuggestedPeriod()
            return
        }
        periodPick = pick
        if periodSuggestionState == .accepted {
            periodSuggestionState = .suggested
        }
    }

    mutating func setChip(_ id: UUID, _ state: ChipState) {
        if let index = people.firstIndex(where: { $0.id == id }) {
            people[index].state = state
            return
        }
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        if state == .accepted {
            for otherIndex in places.indices where otherIndex != index && places[otherIndex].state == .accepted {
                places[otherIndex].state = .suggested
            }
            typedPlace = nil
        }
        places[index].state = state
    }

    mutating func setUseMatch(_ id: UUID, _ value: Bool) {
        if let index = people.firstIndex(where: { $0.id == id }) {
            people[index].useMatch = value
            return
        }
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        places[index].useMatch = value
    }

    mutating func addTypedPerson(_ entity: TypedEntity) {
        switch entity {
        case .existing(let id):
            guard !typedPeople.contains(where: {
                if case .existing(let existingID) = $0 { return existingID == id }
                return false
            }) else { return }
        case .new(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = SpanVerifier.phraseKey(trimmed)
            let duplicateTyped = typedPeople.contains {
                if case .new(let existingName) = $0 {
                    return SpanVerifier.phraseKey(existingName) == key
                }
                return false
            }
            let duplicateChip = people.contains {
                $0.state == .accepted && SpanVerifier.phraseKey($0.span.text) == key
            }
            let duplicateKnown = knownPeople.contains {
                SpanVerifier.phraseKey($0.name) == key
            }
            guard !duplicateTyped, !duplicateChip, !duplicateKnown else { return }
        }
        typedPeople.append(entity)
    }

    mutating func removeTypedPerson(at index: Int) {
        guard typedPeople.indices.contains(index) else { return }
        typedPeople.remove(at: index)
    }

    mutating func setTypedPlace(_ entity: TypedEntity?) {
        if case .new(let name)? = entity,
           name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            typedPlace = nil
            return
        }
        typedPlace = entity
        guard entity != nil else { return }
        for index in places.indices where places[index].state == .accepted {
            places[index].state = .suggested
        }
    }

    mutating func setWhen(_ answer: WhenAnswer) {
        when = answer
    }

    mutating func setRow(_ id: UUID, _ choice: RowChoice) {
        guard let index = followUps.firstIndex(where: { $0.id == id }) else { return }
        followUps[index].choice = choice
    }

    var resolvedTitle: ResolvedTitle? {
        let trimmed = typedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return .typed(trimmed) }
        guard let titleChip, titleChip.state == .accepted else { return nil }
        return .quote(titleChip.span)
    }

    var canFile: Bool {
        resolvedTitle != nil
    }

    func isLive(_ row: FollowUpRow) -> Bool {
        if row.question.templateID == FilingTemplates.who.id {
            guard let slot = row.question.slots.first else { return false }
            return people.contains { $0.state == .accepted && $0.span == slot }
        }
        if row.question.templateID == FilingTemplates.sensoryPlace.id {
            guard let slot = row.question.slots.first else { return false }
            return places.contains { $0.state == .accepted && $0.span == slot }
        }
        return true
    }

    static func unfiledRow(
        status: TranscriptionStatus,
        transcript: CompletedTranscript?
    ) -> UnfiledRow {
        switch status {
        case .pending, .live, .fromFile:
            return .transcribing
        case .complete:
            guard let excerpt = transcript?.excerpt, !excerpt.isEmpty else {
                return .noTranscript
            }
            return .ready(excerpt: excerpt)
        case .failed:
            return .noTranscript
        }
    }
}
