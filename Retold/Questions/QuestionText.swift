import Foundation

/// The text a page or the export shows for a persisted Question (R7b section 3.5).
enum QuestionText {
    /// Question.text, except a period.slot question with a period: re-assembled with
    /// TemplateAssembler.assemble(_:periodTitle:) on period.titleFill, falling back to Question.text
    /// on a throw, so a renamed period shows its current title.
    @MainActor
    static func display(_ question: Question) -> String {
        guard question.templateID == "period.slot", let period = question.period else {
            return question.text
        }
        guard let template = QuestionDeck.template(id: "period.slot"),
              let assembled = try? TemplateAssembler.assemble(template, periodTitle: period.titleFill)
        else { return question.text }
        return assembled.text
    }
}
