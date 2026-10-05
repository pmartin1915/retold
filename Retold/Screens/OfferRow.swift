import SwiftData
import SwiftUI

/// One engine offer with its two actions (R7b section 7.1). Shows `offer.question.text`, never
/// `Question.text`. A throw from either action does nothing visible, and the row stays.
struct OfferRow: View {
    let offer: EngineOffer
    let target: OfferTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayback.self) private var playback
    @Environment(CaptureCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(offer.question.text)
            HStack {
                Button(AppCopy.answerNow) {
                    answerNow()
                }
                // .dontRemember does nothing on broad.open (Question.record), as on the confirm screen.
                if offer.question.templateID != "broad.open" {
                    Button(AppCopy.notThisOne) {
                        notThisOne()
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private func answerNow() {
        playback.stop()
        guard let id = try? QuestionActions.prepareAnswer(offer, target: target, in: modelContext) else {
            return
        }
        let coordinator = coordinator
        Task { @MainActor in
            await coordinator.startCapture(answering: id)
        }
    }

    private func notThisOne() {
        try? QuestionActions.notThisOne(offer, target: target, in: modelContext)
    }
}

/// A `Section(questionsHeader)` with one OfferRow per offer, in the engine's queue order.
/// Omitted when the queue is empty.
struct OfferSection: View {
    let offers: [EngineOffer]
    let target: OfferTarget

    var body: some View {
        if !offers.isEmpty {
            Section(AppCopy.questionsHeader) {
                ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
                    OfferRow(offer: offer, target: target)
                }
            }
        }
    }
}
