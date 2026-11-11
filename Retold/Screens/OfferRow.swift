import SwiftData
import SwiftUI

/// One engine offer with its two actions (R7b section 7.1). Shows `offer.question.text`, never
/// `Question.text`. A throw from either action shows a short alert, and the row stays.
struct OfferRow: View {
    let offer: EngineOffer
    let target: OfferTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayback.self) private var playback
    @Environment(CaptureCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL

    @State private var micBlocked = false
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            // comeup run 3 (F1): questions in the serif face, as StoryCue sets them.
            Text(offer.question.text)
                .fontDesign(DesignTokens.wordsFontDesign)
            HStack {
                // comeup run 2: 44 pt tap height (house style rule 4); the frame sits inside the label.
                Button {
                    answerNow()
                } label: {
                    Text(AppCopy.answerNow).frame(minHeight: 44).contentShape(Rectangle())
                }
                // .dontRemember does nothing on broad.open (Question.record), as on the confirm screen.
                if offer.question.templateID != "broad.open" {
                    Button {
                        notThisOne()
                    } label: {
                        Text(AppCopy.notThisOne).frame(minHeight: 44).contentShape(Rectangle())
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
            Button(AppCopy.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button(AppCopy.cancelButton, role: .cancel) {}
        } message: {
            Text(AppCopy.micDenied)
        }
        .alert(AppCopy.saveFailedTitle, isPresented: $saveFailed) {
            Button(AppCopy.okButton, role: .cancel) {}
        } message: {
            Text(AppCopy.saveFailedMessage)
        }
    }

    private func answerNow() {
        playback.stop()
        let id: UUID
        do {
            id = try QuestionActions.prepareAnswer(offer, target: target, in: modelContext)
        } catch {
            saveFailed = true
            return
        }
        let coordinator = coordinator
        Task { @MainActor in
            await coordinator.startCapture(answering: id)
            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
                micBlocked = true
            }
        }
    }

    private func notThisOne() {
        do {
            try QuestionActions.notThisOne(offer, target: target, in: modelContext)
        } catch {
            saveFailed = true
        }
    }
}

/// A `Section(questionsHeader)` with one OfferRow per offer, in the engine's queue order.
/// Omitted when the queue is empty.
struct OfferSection: View {
    let offers: [EngineOffer]
    let target: OfferTarget
    /// comeup run 3 (C13): under a page's stories, the questions fold into one counted row, as on
    /// the story page (run 2, V5). Unfolded on a page with no stories, where they are the content.
    var folded = false

    var body: some View {
        if !offers.isEmpty {
            if folded {
                Section {
                    DisclosureGroup("\(AppCopy.questionsHeader) (\(offers.count))") {
                        rows
                    }
                }
            } else {
                Section(AppCopy.questionsHeader) {
                    rows
                }
            }
        }
    }

    private var rows: some View {
        ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
            OfferRow(offer: offer, target: target)
        }
    }
}
