import Foundation
import XCTest
@testable import Retold

/// R2's known gap: a one-word span such as "I" verifies (it is verbatim) but cannot fill a slot.
@MainActor
final class SlotGuardTests: XCTestCase {
    private let captureID = UUID()

    private func span(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: end)
    }

    func testPronounsAndFunctionWordsAreDegenerate() {
        for text in ["I", "it", "the", "you and me", "I'm", "...", "x"] {
            XCTAssertTrue(SlotGuard.isDegenerate(text), text)
        }
    }

    func testRealReferentsAreNot() {
        for text in ["Dan", "the lake", "Amy", "swimming", "my grandmother"] {
            XCTAssertFalse(SlotGuard.isDegenerate(text), text)
        }
    }

    func testLintReportsADegenerateSlot() throws {
        let built = try TemplateAssembler.assemble(FilingTemplates.who, slots: [span("I", 0, 1)])
        XCTAssertEqual(built.text, "Who was I to you, back then?")
        XCTAssertEqual(QuestionLint.violations(in: built, template: FilingTemplates.who).map(\.rule), [.degenerateSlot])
    }

    func testFollowUpsNeverAskWhoWasIToYou() {
        var merged = MergedExtract()
        merged.people = [span("I", 0, 1), span("Dan", 1, 2)]
        merged.places = [span("it", 0, 1)]
        merged.timeCues = [span("the", 0, 1)]
        let questions = TemplateAssembler.followUps(from: merged)
        XCTAssertEqual(questions.map(\.templateID), ["broad.open", "when.open", "who.person"])
        XCTAssertEqual(questions.last?.text, "Who was Dan to you, back then?")
    }
}
