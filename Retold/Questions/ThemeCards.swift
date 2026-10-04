import Foundation

/// A theme card (PLAN section 8, Guided Autobiography's themes: themes usable, text not). A second
/// way in beside the periods, for a user who does not think in periods.
struct ThemeCard: Equatable, Sendable {
    let id: String              // "theme.turningPoint" etc.; equals its one template id today
    let title: String
    let templateIDs: [String]
}

enum ThemeCards {
    static let all: [ThemeCard] = [
        ThemeCard(id: "theme.turningPoint", title: "Turning points", templateIDs: ["theme.turningPoint"]),
        ThemeCard(id: "theme.family", title: "Family origins", templateIDs: ["theme.family"]),
        ThemeCard(id: "theme.work", title: "Work", templateIDs: ["theme.work"]),
        ThemeCard(id: "theme.body", title: "Health and the body", templateIDs: ["theme.body"]),
        ThemeCard(id: "theme.close", title: "Love and relationships", templateIDs: ["theme.close"]),
    ]
}

/// The asks for one card: questions whose templateID is in the card's templateIDs and that have no
/// episode, no period and no person (a theme question belongs to no page but its card).
struct ThemeState: Equatable, Sendable {
    var asks: [AskRecord] = []
}

extension ThemeState {
    @MainActor
    init(card: ThemeCard, questions: [Question]) {
        asks = questions
            .filter {
                card.templateIDs.contains($0.templateID)
                    && $0.episode == nil && $0.period == nil && $0.person == nil
            }
            .map { AskRecord($0) }
    }
}
