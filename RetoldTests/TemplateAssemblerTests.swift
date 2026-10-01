import Foundation
import XCTest
@testable import Retold

@MainActor
final class TemplateAssemblerTests: XCTestCase {
    private let captureID = UUID()

    private func span(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: end)
    }

    func testTemplatesDeclareTheirSlotCounts() {
        XCTAssertEqual(FilingTemplates.broad.slotCount, 0)
        XCTAssertEqual(FilingTemplates.when.slotCount, 0)
        for template in [FilingTemplates.whenWithCue, FilingTemplates.who,
                         FilingTemplates.sensoryPlace, FilingTemplates.referent] {
            XCTAssertEqual(template.slotCount, 1, template.id)
        }
    }

    func testAssemblyFillsTheSlotWithTheSpanTextVerbatim() throws {
        let built = try TemplateAssembler.assemble(FilingTemplates.referent, slots: [span("the red canoe", 1, 2)])
        XCTAssertEqual(built.text, "You mentioned the red canoe. Is there anything else about that?")
        XCTAssertEqual(built.templateID, "referent.open")
        XCTAssertEqual(built.slots.map(\.text), ["the red canoe"])
    }

    func testWrongSlotCountThrows() {
        XCTAssertThrowsError(try TemplateAssembler.assemble(FilingTemplates.who, slots: [])) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .slotCountMismatch)
        }
        XCTAssertThrowsError(try TemplateAssembler.assemble(FilingTemplates.broad, slots: [span("x", 0, 1)])) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .slotCountMismatch)
        }
    }

    func testTwoSlotTemplateNeedsBothSpansInOneSegment() throws {
        let two = QuestionTemplate(id: "test.two", cue: .event, pattern: "{slot} and {slot}")
        let segments = [
            TranscriptSegment(text: "Dan by the lake", start: 0, end: 4, isFinal: true),
            TranscriptSegment(text: "later the dock", start: 4, end: 8, isFinal: true),
        ]
        let same = try TemplateAssembler.assemble(
            two, slots: [span("Dan", 0, 4), span("the lake", 0, 4)], segments: segments)
        XCTAssertEqual(same.text, "Dan and the lake")
        XCTAssertThrowsError(try TemplateAssembler.assemble(
            two, slots: [span("Dan", 0, 4), span("the dock", 4, 8)], segments: segments)
        ) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .slotsFromDifferentSegments)
        }
        XCTAssertThrowsError(try TemplateAssembler.assemble(
            two, slots: [span("Dan", 0, 4), span("the lake", 0, 4)])
        )
    }

    func testThreeSlotsAreNeverAllowed() {
        let three = QuestionTemplate(id: "test.three", cue: .event, pattern: "{slot} {slot} {slot}")
        let spans = [span("a", 0, 1), span("b", 0, 1), span("c", 0, 1)]
        XCTAssertThrowsError(try TemplateAssembler.assemble(three, slots: spans))
    }

    func testFollowUpsAreBroadFirstThenWhenThenRotation() {
        var merged = MergedExtract()
        merged.timeCues = [span("the summer before eighth grade", 0, 2)]
        merged.referents = [
            VerifiedReferent(span: span("the canoe", 1, 2), kind: .object),
            VerifiedReferent(span: span("swimming", 2, 3), kind: .activity),
        ]
        merged.places = [span("the lake", 0, 1)]
        merged.people = [span("Dan", 0, 1), span("Amy", 1, 2)]
        let questions = TemplateAssembler.followUps(from: merged, maxFollowUps: 5)
        XCTAssertEqual(
            questions.map(\.templateID),
            ["broad.open", "when.cue", "referent.open", "sensory.place", "who.person", "referent.open", "who.person"])
        XCTAssertEqual(questions[1].text, "You said 'the summer before eighth grade' \u{2014} roughly what year would that be?")
    }

    func testFollowUpsWithNothingVerifiedAreTheTwoSlotlessQuestions() {
        let questions = TemplateAssembler.followUps(from: MergedExtract())
        XCTAssertEqual(questions.map(\.templateID), ["broad.open", "when.open"])
    }

    func testAssembledQuestionBecomesADeckOriginQuestion() throws {
        let built = try TemplateAssembler.assemble(FilingTemplates.who, slots: [span("Dan", 0, 1)])
        let question = built.question()
        XCTAssertEqual(question.origin, .deck)
        XCTAssertEqual(question.text, built.text)
        XCTAssertEqual(question.templateID, "who.person")
        XCTAssertEqual(question.slots, built.slots)
    }
}
