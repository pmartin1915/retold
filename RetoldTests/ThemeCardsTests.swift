import Foundation
import SwiftData
import XCTest
@testable import Retold

final class ThemeCardsTests: XCTestCase {
    private func ask(_ templateID: String, status: QuestionStatus, id: UUID = UUID()) -> AskRecord {
        AskRecord(questionID: id, templateID: templateID, cue: .period, slotKey: "",
                  status: status, lastAskedAt: nil)
    }

    func testFiveCardsInPlanOrder() {
        XCTAssertEqual(
            ThemeCards.all.map(\.id),
            ["theme.turningPoint", "theme.family", "theme.work", "theme.body", "theme.close"])
        XCTAssertEqual(
            ThemeCards.all.map(\.title),
            ["Turning points", "Family origins", "Work", "Health and the body", "Love and relationships"])
    }

    func testEveryCardTemplateIsADeckTemplate() {
        for card in ThemeCards.all {
            for id in card.templateIDs {
                XCTAssertNotNil(QuestionDeck.template(id: id), id)
            }
        }
    }

    func testEveryThemeTemplateIsInExactlyOneCard() {
        let cardTemplateIDs = ThemeCards.all.flatMap(\.templateIDs)
        let deckThemeIDs = QuestionDeck.all.filter { $0.id.hasPrefix("theme.") }.map(\.id)
        XCTAssertFalse(deckThemeIDs.isEmpty)
        for id in deckThemeIDs {
            XCTAssertEqual(cardTemplateIDs.filter { $0 == id }.count, 1, id)
        }
    }

    func testCardTitlesAreWellnessClean() {
        for card in ThemeCards.all {
            XCTAssertTrue(WellnessLint.violations(in: card.title).isEmpty, card.title)
        }
    }

    func testCardQueueOffersItsTemplate() {
        let card = ThemeCards.all[0]
        let offers = QuestionEngine.queue(for: card, state: ThemeState())
        XCTAssertEqual(offers.map(\.question.templateID), ["theme.turningPoint"])
        XCTAssertEqual(offers.first?.channel, .theme)
    }

    func testAnsweredAndRetiredThemeQuestionsAreNotReoffered() {
        let card = ThemeCards.all[2] // theme.work
        XCTAssertTrue(QuestionEngine.queue(
            for: card, state: ThemeState(asks: [ask("theme.work", status: .answered)])).isEmpty)
        XCTAssertTrue(QuestionEngine.queue(
            for: card, state: ThemeState(asks: [ask("theme.work", status: .retired)])).isEmpty)
    }

    func testSkippedThemeQuestionKeepsItsID() {
        let id = UUID()
        let offers = QuestionEngine.queue(
            for: ThemeCards.all[1], state: ThemeState(asks: [ask("theme.family", status: .skipped, id: id)]))
        XCTAssertEqual(offers.first?.existingQuestionID, id)
    }

    func testRetiringOneCardDoesNotQuietAnother() {
        let workCard = ThemeCards.all[2]
        let retiredWork = ThemeState(asks: [ask("theme.work", status: .retired)])
        XCTAssertTrue(QuestionEngine.queue(for: workCard, state: retiredWork).isEmpty)

        // The family card's state does not hold the work ask: its own question is still offered.
        let familyOffers = QuestionEngine.queue(for: ThemeCards.all[1], state: ThemeState())
        XCTAssertEqual(familyOffers.map(\.question.templateID), ["theme.family"])
    }

    @MainActor
    func testThemeStateAdapterTakesOnlyOwnerlessQuestionsOfItsCard() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let episode = Episode(typedTitle: "E")
        context.insert(episode)

        // A theme.work question filed on an episode: not ownerless, so not the card's.
        let filed = Question.fixture(
            text: "What comes to mind when you think of work you've done?",
            templateID: "theme.work", slots: [], cue: .period, origin: .deck)
        context.insert(filed)
        episode.questions.append(filed)

        // A theme.family question: ownerless, but not this card's.
        let family = Question.fixture(
            text: "What comes to mind when you think of where your family comes from?",
            templateID: "theme.family", slots: [], cue: .period, origin: .deck)
        context.insert(family)

        // A theme.work question with no page: the card's.
        let owned = Question.fixture(
            text: "What comes to mind when you think of work you've done?",
            templateID: "theme.work", slots: [], cue: .period, origin: .deck)
        context.insert(owned)
        try context.save()

        let workCard = ThemeCards.all[2]
        let state = ThemeState(card: workCard, questions: [filed, family, owned])
        XCTAssertEqual(state.asks, [AskRecord(owned)])
    }
}
