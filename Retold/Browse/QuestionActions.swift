import Foundation
import SwiftData

/// The page an offer is shown on (R7b section 3.4); it decides where a new Question attaches.
enum OfferTarget {
    case episode(Episode)
    case period(Period)
    case person(Person)
    case theme
}

enum QuestionActionError: Error, Equatable {
    case noEpisodeForPersonOffer    // the person offer's slot capture is in none of the person's episodes
}

/// The writes behind a question row (R7b section 4). The only code outside the R7a filer that
/// persists a Question, and only through `AssembledQuestion.question()`.
@MainActor
enum QuestionActions {
    /// The persisted Question for `offer`, inserting it if new. Saves nothing.
    static func persist(
        _ offer: EngineOffer,
        target: OfferTarget,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> Question {
        // Pending inserts are included, so a second call before any save still finds the first's Question.
        let allQuestions = try context.fetch(FetchDescriptor<Question>())
            + context.insertedModelsArray.compactMap { $0 as? Question }

        if let existingID = offer.existingQuestionID,
           let existing = allQuestions.first(where: { $0.id == existingID }) {
            return existing
        }

        // The double-tap guard: a view's captured offer keeps existingQuestionID == nil until the
        // next render, so a second tap must find the Question the first tap inserted.
        let assembled = offer.question
        let wantedKey = assembled.slots.first.map { SpanVerifier.phraseKey($0.text) } ?? ""
        let duplicate = allQuestions.first { (candidate: Question) -> Bool in
            guard candidate.templateID == assembled.templateID else { return false }
            let key = candidate.slots.first.map { SpanVerifier.phraseKey($0.text) } ?? ""
            guard key == wantedKey else { return false }
            switch target {
            case .episode(let episode):
                return episode.questions.contains { $0.id == candidate.id }
            case .period(let period):
                return candidate.period?.id == period.id && candidate.episode == nil
            case .person(let person):
                return candidate.person?.id == person.id
            case .theme:
                return candidate.episode == nil && candidate.period == nil && candidate.person == nil
            }
        }
        if let duplicate { return duplicate }

        // A person offer must sit in an episode, or PersonState would never see it as asked. Check
        // before inserting anything.
        var personEpisode: Episode?
        if case .person(let person) = target {
            let slotCaptureID = assembled.slots.first?.captureID
            personEpisode = person.episodes.first { (episode: Episode) -> Bool in
                episode.captures.contains { $0.id == slotCaptureID }
            }
            if personEpisode == nil { throw QuestionActionError.noEpisodeForPersonOffer }
        }

        let question = assembled.question(createdAt: now)
        context.insert(question)
        switch target {
        case .episode(let episode):
            episode.questions.append(question)
        case .period(let period):
            question.period = period
        case .person(let person):
            personEpisode?.questions.append(question)
            question.person = person
        case .theme:
            break
        }
        return question
    }

    /// persist, markShown(at: now), save. Returns the question's id for startCapture(answering:).
    static func prepareAnswer(
        _ offer: EngineOffer,
        target: OfferTarget,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> UUID {
        let question = try persist(offer, target: target, in: context, now: now)
        question.markShown(at: now)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return question.id
    }

    /// persist, markShown(at: now), record(.dontRemember), save.
    static func notThisOne(
        _ offer: EngineOffer,
        target: OfferTarget,
        in context: ModelContext,
        now: Date = Date()
    ) throws {
        let question = try persist(offer, target: target, in: context, now: now)
        question.markShown(at: now)
        question.record(.dontRemember)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
