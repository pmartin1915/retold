import SwiftData
import SwiftUI

/// The R5 theme cards (R7b section 7.5): one section per card, its open question rows beneath.
/// A card with no open questions is left out, and when every card is empty the page says so with
/// one action (house style rule 12) instead of showing a blank list.
struct ThemesView: View {
    @Query private var allQuestions: [Question]

    private struct CardOffers: Identifiable {
        let card: ThemeCard
        let offers: [EngineOffer]
        var id: String { card.id }
    }

    private var cardsWithOffers: [CardOffers] {
        ThemeCards.all.compactMap { card in
            let offers = QuestionEngine.queue(
                for: card, state: ThemeState(card: card, questions: allQuestions))
            return offers.isEmpty ? nil : CardOffers(card: card, offers: offers)
        }
    }

    var body: some View {
        let groups = cardsWithOffers
        Group {
            if groups.isEmpty {
                EmptyPage(title: AppCopy.themesEmptyTitle, message: AppCopy.themesEmptyMessage)
            } else {
                List {
                    ForEach(groups) { group in
                        EyebrowSection(group.card.title) {
                            ForEach(Array(group.offers.enumerated()), id: \.offset) { _, offer in
                                OfferRow(offer: offer, target: .theme)
                            }
                        }
                    }
                }
            }
        }
        .paperPage()
        .navigationTitle(AppCopy.themesTitle)
    }
}
