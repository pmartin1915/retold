import Foundation
import SwiftData

struct FilingResult {
    let episode: Episode
    let questionsByRowID: [UUID: Question]
}

enum ConfirmFilerError: Error, Equatable {
    case cannotFile
    case wrongCapture
    case alreadyFiled
}

@MainActor
enum ConfirmFiler {
    @discardableResult
    static func file(
        _ draft: ConfirmDraft,
        capture: Capture,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> FilingResult {
        guard capture.id == draft.captureID else {
            throw ConfirmFilerError.wrongCapture
        }
        if case .quote(let span)? = draft.resolvedTitle, span.captureID != capture.id {
            throw ConfirmFilerError.wrongCapture
        }
        guard capture.episode == nil else {
            throw ConfirmFilerError.alreadyFiled
        }
        guard let resolvedTitle = draft.resolvedTitle else {
            throw ConfirmFilerError.cannotFile
        }

        do {
            let episode: Episode
            switch resolvedTitle {
            case .typed(let title):
                episode = Episode(
                    typedTitle: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdAt: now
                )
            case .quote(let span):
                episode = Episode(titleQuote: span, createdAt: now)
                episode.confirmTitle()
            }
            context.insert(episode)

            episode.captures.append(capture)
            if let transcript = capture.completedTranscript {
                episode.setExcerpt(from: transcript)
            }

            switch draft.periodPick {
            case .none:
                break
            case .existing(let id):
                episode.period = try fetchPeriod(id: id, in: context)
            case .new(let title):
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let periods = try context.fetch(FetchDescriptor<Period>())
                    let nextSortOrder = (periods.map(\.sortOrder).max() ?? -1) + 1
                    let period = Period(title: trimmed, sortOrder: nextSortOrder, createdAt: now)
                    context.insert(period)
                    episode.period = period
                }
            }

            let whenQuestion = draft.whenQuestion.question(createdAt: now)
            episode.setWhenQuestion(whenQuestion)
            switch draft.when {
            case .notSure:
                break
            case .year(let year):
                episode.answerWhen(year: year)
            case .age(let age):
                episode.answerWhen(age: age)
            }

            var storedPeople = try context.fetch(FetchDescriptor<Person>())
            var peopleBySpanKey: [String: Person] = [:]
            for chip in draft.people where chip.state == .accepted {
                let key = SpanVerifier.phraseKey(chip.span.text)
                let person: Person
                if let match = chip.match, chip.useMatch,
                   let existing = try fetchPerson(id: match.id, in: context) {
                    person = existing
                } else if chip.match?.id != nil, !chip.useMatch {
                    person = Person(name: chip.span.text)
                    context.insert(person)
                    storedPeople.append(person)
                } else if let existing = storedPeople.first(where: {
                    SpanVerifier.phraseKey($0.name) == key
                }) {
                    person = existing
                } else {
                    person = Person(name: chip.span.text)
                    context.insert(person)
                    storedPeople.append(person)
                }
                append(person, to: episode)
                peopleBySpanKey[key] = person
            }

            for typed in draft.typedPeople {
                let person: Person?
                switch typed {
                case .existing(let id):
                    person = try fetchPerson(id: id, in: context)
                case .new(let name):
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    let key = SpanVerifier.phraseKey(trimmed)
                    if let existing = storedPeople.first(where: {
                        SpanVerifier.phraseKey($0.name) == key
                    }) {
                        person = existing
                    } else {
                        let newPerson = Person(name: trimmed)
                        context.insert(newPerson)
                        storedPeople.append(newPerson)
                        person = newPerson
                    }
                }
                if let person {
                    append(person, to: episode)
                }
            }

            var storedPlaces = try context.fetch(FetchDescriptor<Place>())
            if let chip = draft.places.first(where: { $0.state == .accepted }) {
                let key = SpanVerifier.phraseKey(chip.span.text)
                let place: Place
                if let match = chip.match, chip.useMatch,
                   let existing = try fetchPlace(id: match.id, in: context) {
                    place = existing
                } else if chip.match?.id != nil, !chip.useMatch {
                    place = Place(name: chip.span.text)
                    context.insert(place)
                    storedPlaces.append(place)
                } else if let existing = storedPlaces.first(where: {
                    SpanVerifier.phraseKey($0.name) == key
                }) {
                    place = existing
                } else {
                    place = Place(name: chip.span.text)
                    context.insert(place)
                    storedPlaces.append(place)
                }
                episode.place = place
            } else if let typedPlace = draft.typedPlace {
                switch typedPlace {
                case .existing(let id):
                    episode.place = try fetchPlace(id: id, in: context)
                case .new(let name):
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let key = SpanVerifier.phraseKey(trimmed)
                        if let existing = storedPlaces.first(where: {
                            SpanVerifier.phraseKey($0.name) == key
                        }) {
                            episode.place = existing
                        } else {
                            let place = Place(name: trimmed)
                            context.insert(place)
                            storedPlaces.append(place)
                            episode.place = place
                        }
                    }
                }
            }

            var questionsByRowID: [UUID: Question] = [:]
            for row in draft.followUps where draft.isLive(row) {
                let question = row.question.question(createdAt: now)
                episode.questions.append(question)
                if row.question.templateID == FilingTemplates.who.id,
                   let slot = row.question.slots.first {
                    question.person = peopleBySpanKey[SpanVerifier.phraseKey(slot.text)]
                }
                if row.choice == .notThisOne {
                    question.record(.dontRemember)
                }
                questionsByRowID[row.id] = question
            }

            if let chip = draft.titleChip, chip.state == .rejected {
                capture.logRejected(.title, text: chip.span.text, at: now)
            }
            if draft.periodSuggestionState == .rejected, let period = draft.suggestedPeriod {
                capture.logRejected(.period, text: period.title, at: now)
            }
            for chip in draft.people where chip.state == .rejected {
                capture.logRejected(.person, text: chip.span.text, at: now)
            }
            for chip in draft.places where chip.state == .rejected {
                capture.logRejected(.place, text: chip.span.text, at: now)
            }

            if let answeredID = capture.answersQuestionID,
               let answered = try fetchQuestion(id: answeredID, in: context) {
                answered.record(.answered)
            }

            try context.save()
            return FilingResult(episode: episode, questionsByRowID: questionsByRowID)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func fetchPeriod(id: UUID, in context: ModelContext) throws -> Period? {
        let wantedID = id
        return try context.fetch(
            FetchDescriptor<Period>(predicate: #Predicate { $0.id == wantedID })
        ).first
    }

    private static func fetchPerson(id: UUID, in context: ModelContext) throws -> Person? {
        let wantedID = id
        return try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == wantedID })
        ).first
    }

    private static func fetchPlace(id: UUID, in context: ModelContext) throws -> Place? {
        let wantedID = id
        return try context.fetch(
            FetchDescriptor<Place>(predicate: #Predicate { $0.id == wantedID })
        ).first
    }

    private static func fetchQuestion(id: UUID, in context: ModelContext) throws -> Question? {
        let wantedID = id
        return try context.fetch(
            FetchDescriptor<Question>(predicate: #Predicate { $0.id == wantedID })
        ).first
    }

    private static func append(_ person: Person, to episode: Episode) {
        guard !episode.people.contains(where: { $0.id == person.id }) else { return }
        episode.people.append(person)
    }
}
