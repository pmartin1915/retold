import Foundation
import XCTest
@testable import Retold

@MainActor
final class QuestionDeckTests: XCTestCase {
    private let captureID = UUID()

    private func span(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: end)
    }

    func testDeckPassesBothLints() {
        for template in QuestionDeck.all {
            let leading = LeadingQuestionLint.violations(in: template.pattern)
            XCTAssertTrue(leading.isEmpty,
                "\(template.id): \(leading.map(\.rule.rawValue).joined(separator: ", "))")
            let wellness = WellnessLint.violations(in: template.pattern)
            XCTAssertTrue(wellness.isEmpty,
                "\(template.id): \(wellness.map(\.term).joined(separator: ", "))")
        }
    }

    func testIDsAndPatternsAreUnique() {
        XCTAssertEqual(Set(QuestionDeck.all.map(\.id)).count, QuestionDeck.all.count)
        XCTAssertEqual(Set(QuestionDeck.all.map(\.pattern)).count, QuestionDeck.all.count)
    }

    func testSlotsStayWithinOne() {
        for template in QuestionDeck.all {
            XCTAssertLessThanOrEqual(template.slotCount, 2, template.id)
            XCTAssertNotEqual(template.slotCount, 2, template.id)
        }
    }

    func testDeckStartsWithFilingTemplates() {
        XCTAssertEqual(Array(QuestionDeck.all.prefix(FilingTemplates.all.count)), FilingTemplates.all)
    }

    func testDeckCountIsExactly25() {
        XCTAssertEqual(QuestionDeck.all.count, 25)
    }

    func testEveryCueKindIsRepresented() {
        let cues = Set(QuestionDeck.all.map(\.cue))
        for cue in [CueKind.period, .event, .sensory, .people, .sequence] {
            XCTAssertTrue(cues.contains(cue), cue.rawValue)
        }
    }

    func testFollowUpTemplateIDsAreInTheDeck() {
        let deckIDs = Set(QuestionDeck.all.map(\.id))

        var withTime = MergedExtract()
        withTime.timeCues = [span("the summer before eighth grade", 0, 2)]
        withTime.referents = [
            VerifiedReferent(span: span("the canoe", 1, 2), kind: .object),
            VerifiedReferent(span: span("swimming", 2, 3), kind: .activity),
        ]
        withTime.places = [span("the lake", 0, 1), span("the dock", 3, 4)]
        withTime.people = [span("Dan", 0, 1), span("Amy", 1, 2)]
        for question in TemplateAssembler.followUps(from: withTime) {
            XCTAssertTrue(deckIDs.contains(question.templateID), question.templateID)
        }

        var withoutTime = MergedExtract()
        withoutTime.people = [span("Amy", 0, 1)]
        for question in TemplateAssembler.followUps(from: withoutTime) {
            XCTAssertTrue(deckIDs.contains(question.templateID), question.templateID)
        }
    }
}
