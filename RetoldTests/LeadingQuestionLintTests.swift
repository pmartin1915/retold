import Foundation
import XCTest
@testable import Retold

@MainActor
final class LeadingQuestionLintTests: XCTestCase {
    private func rules(in pattern: String) -> [LeadingRule] {
        LeadingQuestionLint.violations(in: pattern).map(\.rule)
    }

    // MARK: One negative per rule (PLAN section 7 table)

    func testProperNoun() {
        XCTAssertTrue(rules(in: "Who was Dan to you?").contains(.properNoun))
    }

    func testNumeral() {
        XCTAssertTrue(rules(in: "What happened in 1998?").contains(.numeral))
    }

    func testEmotionWord() {
        XCTAssertTrue(rules(in: "Were you scared, back then?").contains(.emotionWord))
    }

    func testPresupposingSequence() {
        XCTAssertTrue(rules(in: "What happened the next summer?").contains(.presupposingSequence))
    }

    func testBareDefinite() {
        XCTAssertTrue(rules(in: "What do you remember about the drive home?").contains(.bareDefinite))
    }

    func testIntensifier() {
        XCTAssertTrue(rules(in: "What do you remember most?").contains(.intensifier))
    }

    func testAlternativeQuestion() {
        XCTAssertTrue(rules(in: "Did it end badly, or just fade?").contains(.alternativeQuestion))
    }

    func testTagQuestion() {
        XCTAssertTrue(rules(in: "It was summer, wasn't it?").contains(.tagQuestion))
    }

    func testClosedQuestion() {
        XCTAssertTrue(rules(in: "Was it summer?").contains(.closedQuestion))
    }

    func testUnmentionedChannel() {
        XCTAssertTrue(rules(in: "What did the place smell like?").contains(.unmentionedChannel))
    }

    // MARK: Kimi's five worst and PLAN's own failures, each naming its rule

    func testAuthoredNegativesNameTheirRule() {
        XCTAssertTrue(rules(in: "What was {slot} like when they were annoyed?").contains(.emotionWord))
        XCTAssertTrue(rules(in: "What is something {slot} said that you can still hear?").contains(.presupposingSequence))
        XCTAssertTrue(rules(in: "How did that day end?").contains(.presupposingSequence))
        XCTAssertTrue(rules(in: "What happened the next summer?").contains(.presupposingSequence))
        let smell = rules(in: "What did the place smell like?")
        XCTAssertTrue(smell.contains(.unmentionedChannel))
        XCTAssertTrue(smell.contains(.bareDefinite))
        XCTAssertTrue(rules(in: "You mentioned the {slot}. Is there anything else?").contains(.bareDefinite))
        // One channel noun is not a report-everything sentence, so "the smell" fails.
        XCTAssertTrue(rules(in: "Anything about {slot} \u{2014} the smell?").contains(.bareDefinite))
    }

    // MARK: Positives

    func testFilingTemplatesPassWithZeroViolations() {
        for template in FilingTemplates.all {
            XCTAssertTrue(LeadingQuestionLint.violations(in: template.pattern).isEmpty, template.id)
        }
    }

    func testOpenPatternsPassWithZeroViolations() {
        let patterns = [
            "When you think of that place, what comes to mind first?",
            "Is there anything about how {slot} talked that stays with you?",
            "Does this connect to anything else you've thought about since?",
        ]
        for pattern in patterns {
            XCTAssertTrue(LeadingQuestionLint.violations(in: pattern).isEmpty, pattern)
        }
    }

    func testPronounIIsNotAProperNoun() {
        XCTAssertTrue(LeadingQuestionLint.violations(in: "Is there anything I should ask?").isEmpty)
    }

    func testCapitalAfterTerminatorStartsAClause() {
        XCTAssertTrue(LeadingQuestionLint.violations(in: "Anything else? However small.").isEmpty)
    }

    func testCapitalAfterEmDashStartsAClause() {
        XCTAssertTrue(LeadingQuestionLint.violations(in: "You mentioned {slot} \u{2014} Is there anything else?").isEmpty)
    }

    func testReportEverythingNeedsAnAnythingOpener() {
        XCTAssertTrue(rules(in: "What about the light, the sounds?").contains(.bareDefinite))
    }

    func testSlotAloneIsNeverLinted() {
        XCTAssertTrue(LeadingQuestionLint.violations(in: "{slot}").isEmpty)
    }
}
