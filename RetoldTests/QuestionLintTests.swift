import Foundation
import XCTest
@testable import Retold

/// One failing leading question per reject-list rule of PLAN section 7, each with a passing twin.
@MainActor
final class QuestionLintTests: XCTestCase {
    private func rules(_ pattern: String, _ context: LintContext = LintContext()) -> Set<LintRule> {
        Set(QuestionLint.literalViolations(in: pattern, context: context).map(\.rule))
    }

    func testProperNounNotInTheTranscriptIsRejected() {
        XCTAssertTrue(rules("Was Dan there when you got home?").contains(.properNoun))
        XCTAssertEqual(rules("Was anyone there when you got home?"), [])
        XCTAssertEqual(rules("Was Dan there when you got home?", LintContext(allowedNames: ["dan"])), [])
    }

    func testNumeralsAreRejected() {
        XCTAssertTrue(rules("What happened in 1998?").contains(.numeral))
        XCTAssertTrue(rules("Was it two summers?").contains(.numeral))
        XCTAssertEqual(rules("What happened that year?"), [])
        XCTAssertEqual(rules("How do you remember it \u{2014} one moment, a stretch of days, something else?"), [])
    }

    func testEmotionWordsAreRejectedForTheUserAndForOthers() {
        XCTAssertTrue(rules("How did it go when you were scared?").contains(.emotion))
        XCTAssertTrue(rules("Was your brother annoyed?").contains(.emotion))
        XCTAssertTrue(rules("Were you worried?").contains(.emotion))
        XCTAssertEqual(rules("Is there anything else about that?"), [])
    }

    func testOrdinalsAndQuantifiersAreRejected() {
        XCTAssertTrue(rules("What happened the next summer?").contains(.ordinal))
        XCTAssertTrue(rules("Did you always go there?").contains(.ordinal))
        XCTAssertTrue(rules("Did he finally leave?").contains(.ordinal))
        XCTAssertTrue(rules("Do you still go there?").contains(.ordinal))
        XCTAssertTrue(rules("Was that the first time?").contains(.ordinal))
        XCTAssertEqual(rules("Anything else at all, however small?"), [])
    }

    func testBareDefiniteDescriptionsAreRejected() {
        XCTAssertTrue(rules("What was the argument about?").contains(.bareDefinite))
        XCTAssertTrue(rules("How was the drive home?").contains(.bareDefinite))
        XCTAssertEqual(rules("What was the argument about?", LintContext(allowedDefinites: ["argument"])), [])
        XCTAssertEqual(rules("You mentioned {slot}. Is there anything else about that?"), [])
    }

    func testIntensifiersAreRejected() {
        XCTAssertTrue(rules("Do you remember it vividly?").contains(.intensifier))
        XCTAssertTrue(rules("Does anything stand out?").contains(.intensifier))
        XCTAssertEqual(rules("Is there anything about how she talked that stays with you?"), [])
    }

    func testAlternativeAndTagFormsAreRejected() {
        XCTAssertTrue(rules("Did it end badly, or just fade?").contains(.alternative))
        XCTAssertTrue(rules("That was a hard summer, wasn\u{2019}t it?").contains(.alternative))
        XCTAssertTrue(rules("You liked it there, right?").contains(.alternative))
        XCTAssertEqual(rules("How did it end?"), [])
    }

    func testAChannelTheTranscriptNeverMentionedIsRejected() {
        XCTAssertTrue(rules("What did it smell like?").contains(.unmentionedChannel))
        XCTAssertTrue(rules("What were you wearing?").contains(.unmentionedChannel))
        XCTAssertTrue(rules("Was it raining?").contains(.unmentionedChannel))
        XCTAssertTrue(rules("Did you smell smoke?").contains(.unmentionedChannel))
        let mentioned = LintContext(mentionedChannels: SensoryChannel.mentioned(in: "The whole place smelled of smoke."))
        XCTAssertEqual(rules("What did it smell like?", mentioned), [])
    }

    func testReportEverythingFormIsAllowedWithoutMentionedChannels() {
        XCTAssertEqual(rules("Anything about {slot} itself \u{2014} the light, the sounds, the weather? However small."), [])
    }

    func testSlotContentIsNotLinted() throws {
        let canoe = VerifiedSpan.fixture(text: "Dan's 3 red canoes", captureID: UUID(), start: 0, end: 1)
        let built = try TemplateAssembler.assemble(FilingTemplates.referent, slots: [canoe])
        XCTAssertEqual(QuestionLint.violations(in: built, template: FilingTemplates.referent), [])
    }
}
