import Foundation
import XCTest
@testable import Retold

/// The authored deck must pass its own lint (PLAN section 7: "the authored deck must pass it in CI
/// before any of it ships"). `FilingTemplates.all` is walked, so a new template cannot dodge this.
@MainActor
final class DeckLintTests: XCTestCase {
    private let captureID = UUID()

    private func span(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: end)
    }

    func testEveryAuthoredTemplateIsCleanUnderTheStrictestContext() {
        XCTAssertEqual(FilingTemplates.all.count, 6)
        XCTAssertEqual(Set(FilingTemplates.all.map(\.id)).count, FilingTemplates.all.count)
        for template in FilingTemplates.all {
            XCTAssertEqual(QuestionLint.violations(in: template), [], template.id)
        }
    }

    func testTheOnlyAuditedExemptionIsTheDateUnitAlternative() {
        XCTAssertEqual(QuestionLint.exemptions.map(\.templateID), ["when.open"])
        XCTAssertEqual(QuestionLint.exemptions.map(\.rule), [.alternative])
        // The exemption is real: without it the template trips the rule.
        let raw = QuestionLint.literalViolations(in: FilingTemplates.when.pattern).map(\.rule)
        XCTAssertEqual(raw, [.alternative])
    }

    func testEveryFollowUpFromAFullExtractLintsClean() {
        var merged = MergedExtract()
        merged.timeCues = [span("the summer before eighth grade", 0, 2)]
        merged.referents = [
            VerifiedReferent(span: span("Dan's 3 red canoes", 1, 2), kind: .object),
            VerifiedReferent(span: span("swimming", 2, 3), kind: .activity),
        ]
        merged.places = [span("the lake", 0, 1)]
        merged.people = [span("Dan", 0, 1), span("Amy", 1, 2)]
        let questions = TemplateAssembler.followUps(from: merged, maxFollowUps: 8)
        XCTAssertGreaterThanOrEqual(questions.count, 6)
        for question in questions {
            guard let template = FilingTemplates.all.first(where: { $0.id == question.templateID }) else {
                XCTFail("unknown template \(question.templateID)")
                continue
            }
            XCTAssertEqual(QuestionLint.violations(in: question, template: template), [], question.text)
        }
    }
}
