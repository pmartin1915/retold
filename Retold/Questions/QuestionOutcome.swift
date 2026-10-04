import Foundation

/// The user's response to a shown question (PLAN section 7 retirement rule).
enum QuestionOutcome: String, Sendable {
    case answered, dontRemember, skipped
}

extension Question {
    /// The question was put in front of the user: askedCount += 1, lastAskedAt = date.
    func markShown(at date: Date = Date()) {
        askedCount += 1
        lastAskedAt = date
    }

    /// Applies the user's response. False, and nothing changes, if status is .answered
    /// or .retired.
    ///
    /// `broad.open` is the per-capture opener: it is never retired and never logs a
    /// negative, so `.dontRemember` and `.skipped` return true and leave it open. A
    /// second `.skipped` on any other question retires it — the negative is read off
    /// `status`, so no new field is needed.
    @discardableResult
    func record(_ outcome: QuestionOutcome) -> Bool {
        guard status != .answered, status != .retired else { return false }
        if templateID == "broad.open" {
            if outcome == .answered { status = .answered }
            return true
        }
        switch (status, outcome) {
        case (.open, .answered), (.skipped, .answered):
            status = .answered
        case (.open, .dontRemember), (.skipped, .dontRemember), (.skipped, .skipped):
            status = .retired
        case (.open, .skipped):
            status = .skipped
        case (.answered, _), (.retired, _):
            return false
        }
        return true
    }
}
