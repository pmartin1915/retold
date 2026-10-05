import SwiftData
import SwiftUI

/// A period's page (R7b section 7.5): its open questions (for an empty period, the R5 opener),
/// then its episodes, newest first.
struct PeriodView: View {
    let period: Period

    @Query private var allQuestions: [Question]

    var body: some View {
        List {
            OfferSection(
                offers: QuestionEngine.queue(for: PeriodState(period: period, questions: allQuestions)),
                target: .period(period)
            )
            Section {
                ForEach(period.episodes.newestFirst()) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        }
        .navigationTitle(period.title)
    }
}
