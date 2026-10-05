import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class QuestionTextTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    private func periodSlotQuestion(for period: Period) throws -> Question {
        let template = try XCTUnwrap(QuestionDeck.template(id: "period.slot"))
        let assembled = try TemplateAssembler.assemble(template, periodTitle: period.titleFill)
        let question = assembled.question(createdAt: now)
        context.insert(question)
        question.period = period
        return question
    }

    func testPeriodSlotUsesCurrentTitle() throws {
        let period = Period(title: "Early childhood", sortOrder: 0, createdAt: now)
        context.insert(period)
        let question = try periodSlotQuestion(for: period)
        XCTAssertEqual(QuestionText.display(question), question.text)

        period.title = "The farm years"
        let display = QuestionText.display(question)
        XCTAssertNotEqual(display, question.text)
        XCTAssertTrue(display.contains("The farm years"))
        XCTAssertFalse(display.contains("Early childhood"))
    }

    func testOtherQuestionUsesStoredText() throws {
        let template = try XCTUnwrap(QuestionDeck.template(id: "period.else"))
        let assembled = try TemplateAssembler.assemble(template, slots: [])
        let question = assembled.question(createdAt: now)
        context.insert(question)
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        question.period = period
        XCTAssertEqual(QuestionText.display(question), assembled.text)
    }

    func testPeriodSlotFallsBackOnAssembleThrow() throws {
        let period = Period(title: "Early childhood", sortOrder: 0, createdAt: now)
        context.insert(period)
        let question = try periodSlotQuestion(for: period)
        let stored = question.text

        period.title = "   "
        let template = try XCTUnwrap(QuestionDeck.template(id: "period.slot"))
        XCTAssertThrowsError(
            try TemplateAssembler.assemble(template, periodTitle: period.titleFill)
        ) { error in
            XCTAssertEqual(error as? TemplateAssemblyError, .emptySlot)
        }
        XCTAssertEqual(QuestionText.display(question), stored)
    }
}
