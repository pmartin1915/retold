import SwiftData
import SwiftUI

/// The R5 theme cards (R7b section 7.5): one section per card, its open question rows beneath.
struct ThemesView: View {
    @Query private var allQuestions: [Question]

    var body: some View {
        List {
            ForEach(ThemeCards.all, id: \.id) { card in
                Section(card.title) {
                    let offers = QuestionEngine.queue(
                        for: card, state: ThemeState(card: card, questions: allQuestions))
                    ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
                        OfferRow(offer: offer, target: .theme)
                    }
                }
            }
        }
        .navigationTitle(AppCopy.themesTitle)
    }
}
