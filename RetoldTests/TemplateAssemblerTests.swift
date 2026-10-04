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
        let two = QuestionTemplate.fixture(id: "test.two", cue: .event, pattern: "{slot} and {slot}")
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
        let three = QuestionTemplate.fixture(id: "test.three", cue: .event, pattern: "{slot} {slot} {slot}")
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

    /// The R4.5 production constructor copies every field out of the assembled question.
    func testQuestionFromAssembledCopiesEveryField() throws {
        let built = try TemplateAssembler.assemble(FilingTemplates.who, slots: [span("Dan", 0, 1)])
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let question = Question(assembled: built, createdAt: createdAt)
        XCTAssertEqual(question.origin, .deck)
        XCTAssertEqual(question.text, built.text)
        XCTAssertEqual(question.templateID, built.templateID)
        XCTAssertEqual(question.slots, built.slots)
        XCTAssertEqual(question.cue, built.cue)
        XCTAssertEqual(question.status, .open)
        XCTAssertEqual(question.askedCount, 0)
        XCTAssertEqual(question.createdAt, createdAt)
    }

    func testSlotMadeOnlyOfFunctionWordsThrows() {
        for text in ["I", "the", "um, you"] {
            XCTAssertThrowsError(try TemplateAssembler.assemble(FilingTemplates.who, slots: [span(text, 0, 1)])) {
                XCTAssertEqual($0 as? TemplateAssemblyError, .slotIsFunctionWord)
            }
        }
    }

    func testFollowUpsSkipAFunctionWordPersonButKeepAContentWordOne() {
        var onlyI = MergedExtract()
        onlyI.people = [span("I", 0, 1)]
        XCTAssertFalse(TemplateAssembler.followUps(from: onlyI).contains { $0.templateID == "who.person" })

        var withContent = MergedExtract()
        withContent.people = [span("my aunt", 0, 1)]
        XCTAssertTrue(TemplateAssembler.followUps(from: withContent).contains { $0.templateID == "who.person" })
    }
}

// MARK: period.slot, the one non-span fill (R5)

@MainActor
extension TemplateAssemblerTests {
    private var periodSlotTemplate: QuestionTemplate {
        QuestionDeck.template(id: "period.slot")!
    }

    func testPeriodTitleFillsPeriodSlot() throws {
        let built = try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("Twenties"))
        XCTAssertEqual(built.text, "When you think of Twenties, what comes back first?")
        XCTAssertEqual(built.slots, [])
        XCTAssertEqual(built.templateID, "period.slot")
        XCTAssertEqual(built.cue, .period)
    }

    func testPeriodTitleIsTrimmed() throws {
        let built = try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("  High school \n"))
        XCTAssertEqual(built.text, "When you think of High school, what comes back first?")
    }

    func testPeriodTitleRejectsOtherTemplates() {
        for template in [FilingTemplates.who, FilingTemplates.broad] {
            XCTAssertThrowsError(try TemplateAssembler.assemble(
                template, periodTitle: PeriodTitleFill.fixture("High school"))) {
                XCTAssertEqual($0 as? TemplateAssemblyError, .notAPeriodTitleTemplate)
            }
        }
    }

    func testPeriodTitleRejectsEmpty() {
        XCTAssertThrowsError(try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("   "))) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .emptySlot)
        }
    }

    func testPeriodTitleRejectsFunctionWordsOnly() {
        XCTAssertThrowsError(try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("That"))) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .slotIsFunctionWord)
        }
    }

    func testPeriodTitleWithSlotMarkerIsNotReexpanded() throws {
        let built = try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("{slot} years"))
        XCTAssertEqual(built.text, "When you think of {slot} years, what comes back first?")
    }

    func testPeriodTitleNewlinesBecomeOneSpace() throws {
        let built = try TemplateAssembler.assemble(
            periodSlotTemplate, periodTitle: PeriodTitleFill.fixture("High\n\nschool"))
        XCTAssertTrue(built.text.contains("of High school,"), built.text)
    }

    func testPeriodTitleRejectsFixtureWithWrongSlotCount() {
        let noSlot = QuestionTemplate.fixture(id: "period.slot", cue: .period, pattern: "No slot here?")
        XCTAssertThrowsError(try TemplateAssembler.assemble(
            noSlot, periodTitle: PeriodTitleFill.fixture("High school"))) {
            XCTAssertEqual($0 as? TemplateAssemblyError, .notAPeriodTitleTemplate)
        }
    }

    func testPeriodTitleFillFromPeriod() {
        let period = Period(title: "Camp Lakeview", sortOrder: 0)
        XCTAssertEqual(period.titleFill.text, "Camp Lakeview")
    }
}
