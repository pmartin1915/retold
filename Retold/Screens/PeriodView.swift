import SwiftData
import SwiftUI

/// A period's page (R7b section 7.5): its open questions (for an empty period, the R5 opener),
/// then its episodes, newest first.
struct PeriodView: View {
    let period: Period

    @Query private var allQuestions: [Question]

    var body: some View {
        let offers = QuestionEngine.queue(for: PeriodState(period: period, questions: allQuestions))
        Group {
            if offers.isEmpty && period.episodes.isEmpty {
                EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPeriodMessage)
            } else {
                List {
                    // comeup run 3 (C13): the stories first, then the questions.
                    Section {
                        ForEach(period.episodes.newestFirst()) { episode in
                            EpisodeRow(episode: episode)
                        }
                    }
                    OfferSection(offers: offers, target: .period(period), folded: !period.episodes.isEmpty)
                }
            }
        }
        .paperPage()
        .navigationTitle(period.title)
    }
}
