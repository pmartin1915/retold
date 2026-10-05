import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class QuestionActionsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var captureAt: Date { now.addingTimeInterval(-100) }

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    // MARK: Fixtures

    private func makeEpisode() throws -> (episode: Episode, capture: Capture) {
        let capture = Capture(audioFileName: "memory.m4a", duration: 5, createdAt: captureAt)
        context.insert(capture)
        try capture.completeTranscript([
            TranscriptSegment(text: "we sat on the porch", start: 0, end: 5, isFinal: true),
        ])
        let episode = Episode(typedTitle: "The porch", createdAt: captureAt)
        context.insert(episode)
        episode.captures.append(capture)
        try context.save()
        return (episode, capture)
    }

    /// A person named in `capture`, with the persisted who.person question that makes the person
    /// engine offer its people.* cues.
    private func makePerson(in episode: Episode, capture: Capture) throws -> Person {
        let person = Person(name: "Aunt Rosa")
        context.insert(person)
        episode.people.append(person)
        let span = VerifiedSpan.fixture(text: "Aunt Rosa", captureID: capture.id, start: 0, end: 1)
        let who = try TemplateAssembler.assemble(FilingTemplates.who, slots: [span]).question(createdAt: captureAt)
        context.insert(who)
        episode.questions.append(who)
        who.person = person
        try context.save()
        return person
    }

    private func episodeOffer(_ episode: Episode, templateID: String = "event.else") throws -> EngineOffer {
        let queue = QuestionEngine.queue(for: EpisodeState(episode: episode))
        return try XCTUnwrap(queue.first { $0.question.templateID == templateID })
    }

    private func periodOffer(_ period: Period) throws -> EngineOffer {
        let questions = try context.fetch(FetchDescriptor<Question>())
        let queue = QuestionEngine.queue(for: PeriodState(period: period, questions: questions))
        return try XCTUnwrap(queue.first)
    }

    private func personOffer(_ person: Person, templateID: String = "people.describe") throws -> EngineOffer {
        let queue = QuestionEngine.queue(for: PersonState(person: person))
        return try XCTUnwrap(queue.first { $0.question.templateID == templateID })
    }

    private func themeOffer() throws -> EngineOffer {
        let card = ThemeCards.all[0]
        let questions = try context.fetch(FetchDescriptor<Question>())
        let queue = QuestionEngine.queue(for: card, state: ThemeState(card: card, questions: questions))
        return try XCTUnwrap(queue.first)
    }

    private func questionCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Question>())
    }

    // MARK: persist

    func testEpisodeOfferPersistedOnEpisode() throws {
        let (episode, _) = try makeEpisode()
        let offer = try episodeOffer(episode)
        XCTAssertNil(offer.existingQuestionID)

        let question = try QuestionActions.persist(offer, target: .episode(episode), in: context, now: now)
        try context.save()

        XCTAssertEqual(question.templateID, "event.else")
        XCTAssertEqual(question.createdAt, now)
        XCTAssertEqual(question.episode?.id, episode.id)
        XCTAssertTrue(episode.questions.contains { $0.id == question.id })
        XCTAssertEqual(question.status, .open)
        XCTAssertEqual(question.askedCount, 0)
    }

    func testExistingOfferReused() throws {
        let (episode, _) = try makeEpisode()
        let first = try QuestionActions.persist(
            try episodeOffer(episode), target: .episode(episode), in: context, now: now)
        try context.save()
        let before = try questionCount()

        let again = try episodeOffer(episode)
        XCTAssertEqual(again.existingQuestionID, first.id)
        let second = try QuestionActions.persist(again, target: .episode(episode), in: context, now: now)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(try questionCount(), before)
    }

    func testMissingExistingIDPersistsNew() throws {
        let (episode, _) = try makeEpisode()
        let real = try episodeOffer(episode)
        let stale = EngineOffer(question: real.question, existingQuestionID: UUID())
        let before = try questionCount()

        let question = try QuestionActions.persist(stale, target: .episode(episode), in: context, now: now)
        try context.save()

        XCTAssertEqual(try questionCount(), before + 1)
        XCTAssertNotEqual(question.id, stale.existingQuestionID)
        XCTAssertEqual(question.templateID, real.question.templateID)
    }

    func testPeriodOfferHasPeriodAndNoEpisode() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()
        let offer = try periodOffer(period)
        XCTAssertEqual(offer.question.templateID, "period.slot")

        let question = try QuestionActions.persist(offer, target: .period(period), in: context, now: now)
        try context.save()

        XCTAssertEqual(question.period?.id, period.id)
        XCTAssertNil(question.episode)
        XCTAssertNil(question.person)
    }

    func testPersonOfferLandsInSlotEpisodeWithPerson() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let offer = try personOffer(person)

        let question = try QuestionActions.persist(offer, target: .person(person), in: context, now: now)
        try context.save()

        XCTAssertEqual(question.person?.id, person.id)
        XCTAssertEqual(question.episode?.id, episode.id)
        XCTAssertTrue(episode.questions.contains { $0.id == question.id })
    }

    func testPersonOfferSeenAsAskedAfterPersist() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let offer = try personOffer(person)
        XCTAssertNil(offer.existingQuestionID)

        let question = try QuestionActions.persist(offer, target: .person(person), in: context, now: now)
        try context.save()

        let rebuilt = try personOffer(person)
        XCTAssertEqual(rebuilt.question.templateID, offer.question.templateID)
        XCTAssertEqual(rebuilt.existingQuestionID, question.id)
    }

    func testPersonOfferWithoutEpisodeThrowsBeforeInsert() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let offer = try personOffer(person)
        // A person whose episodes hold no capture with the offer's slot.
        let stranger = Person(name: "Stranger")
        context.insert(stranger)
        try context.save()
        let before = try questionCount()

        XCTAssertThrowsError(
            try QuestionActions.persist(offer, target: .person(stranger), in: context, now: now)
        ) { error in
            XCTAssertEqual(error as? QuestionActionError, .noEpisodeForPersonOffer)
        }
        XCTAssertEqual(try questionCount(), before)
        XCTAssertFalse(context.hasChanges)
    }

    func testThemeOfferHasNoRelations() throws {
        let offer = try themeOffer()
        let question = try QuestionActions.persist(offer, target: .theme, in: context, now: now)
        try context.save()

        XCTAssertNil(question.episode)
        XCTAssertNil(question.period)
        XCTAssertNil(question.person)
        XCTAssertEqual(question.templateID, offer.question.templateID)
    }

    func testSecondPersistOfSameNewOfferReusesQuestion() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()

        let cases: [(OfferTarget, EngineOffer)] = [
            (.episode(episode), try episodeOffer(episode)),
            (.period(period), try periodOffer(period)),
            (.person(person), try personOffer(person)),
            (.theme, try themeOffer()),
        ]
        for (target, offer) in cases {
            XCTAssertNil(offer.existingQuestionID)
            let before = try questionCount()
            let first = try QuestionActions.persist(offer, target: target, in: context, now: now)
            let second = try QuestionActions.persist(offer, target: target, in: context, now: now)
            XCTAssertEqual(first.id, second.id)
            XCTAssertEqual(try questionCount(), before + 1)
            try context.save()
        }
    }

    func testRetiringPersonOfferHidesSiblingsOnSameSlot() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let offer = try personOffer(person, templateID: "people.describe")
        XCTAssertTrue(
            QuestionEngine.queue(for: PersonState(person: person))
                .contains { $0.question.templateID == "people.talk" })

        try QuestionActions.notThisOne(offer, target: .person(person), in: context, now: now)

        let remaining = QuestionEngine.queue(for: PersonState(person: person))
        XCTAssertFalse(remaining.contains { QuestionEngine.personTemplateIDs.contains($0.question.templateID) })
    }

    // MARK: prepareAnswer and notThisOne

    func testPrepareAnswerMarksShownAndSaves() throws {
        let (episode, _) = try makeEpisode()
        let offer = try episodeOffer(episode)

        let id = try QuestionActions.prepareAnswer(offer, target: .episode(episode), in: context, now: now)

        let reopened = ModelContext(container)
        let questions = try reopened.fetch(FetchDescriptor<Question>())
        let saved = try XCTUnwrap(questions.first { $0.id == id })
        XCTAssertEqual(saved.askedCount, 1)
        XCTAssertEqual(saved.lastAskedAt, now)
        XCTAssertEqual(saved.status, .open)
    }

    func testNotThisOneRetires() throws {
        let (episode, _) = try makeEpisode()
        let offer = try episodeOffer(episode)

        try QuestionActions.notThisOne(offer, target: .episode(episode), in: context, now: now)

        let reopened = ModelContext(container)
        let saved = try XCTUnwrap(
            try reopened.fetch(FetchDescriptor<Question>()).first { $0.templateID == "event.else" })
        XCTAssertEqual(saved.status, .retired)
        XCTAssertEqual(saved.askedCount, 1)
        XCTAssertEqual(saved.lastAskedAt, now)
    }

    func testNotThisOneConsumesBroadOpener() throws {
        let (episode, _) = try makeEpisode()
        let before = QuestionEngine.queue(for: EpisodeState(episode: episode))
        XCTAssertEqual(before.first?.question.templateID, "broad.open")
        let broad = try XCTUnwrap(before.first)

        // `now` is later than the capture's createdAt, so the shown-at mark lands after it.
        try QuestionActions.notThisOne(broad, target: .episode(episode), in: context, now: now)

        let after = QuestionEngine.queue(for: EpisodeState(episode: episode))
        XCTAssertNotEqual(after.first?.question.templateID, "broad.open")
        XCTAssertFalse(after.contains { $0.question.templateID == "broad.open" })
    }

    func testWall3PersistedQuestionsAreDeckOrigin() throws {
        let (episode, capture) = try makeEpisode()
        let person = try makePerson(in: episode, capture: capture)
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()

        _ = try QuestionActions.persist(try episodeOffer(episode), target: .episode(episode), in: context, now: now)
        _ = try QuestionActions.persist(try periodOffer(period), target: .period(period), in: context, now: now)
        _ = try QuestionActions.persist(try personOffer(person), target: .person(person), in: context, now: now)
        _ = try QuestionActions.persist(try themeOffer(), target: .theme, in: context, now: now)
        try context.save()

        let deckIDs = Set(QuestionDeck.all.map(\.id))
        let all = try context.fetch(FetchDescriptor<Question>())
        XCTAssertGreaterThanOrEqual(all.count, 4)
        for question in all {
            XCTAssertEqual(question.origin, .deck)
            XCTAssertTrue(deckIDs.contains(question.templateID), question.templateID)
        }
    }
}
