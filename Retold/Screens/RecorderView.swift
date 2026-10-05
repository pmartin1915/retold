import Foundation
import SwiftData
import SwiftUI

/// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
/// (R7 replaces this screen; no design pass).
struct RecorderView: View {
    let coordinator: CaptureCoordinator
    /// Approximation of "when the phase became .recording" (spec allows approximate):
    /// the clock starts when this view appears for a capture.
    @State private var startedAt = Date()
    @Environment(\.modelContext) private var modelContext
    /// R7b: the question this capture answers, fetched once on appear. Hidden when not found.
    @State private var answeringText: String?

    private var isInterrupted: Bool {
        if case .interrupted = coordinator.state.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 20) {
            if coordinator.state.answering != nil {
                Text(AppCopy.answeringLabel)
                    .foregroundStyle(.secondary)
                if let answeringText {
                    Text(answeringText)
                }
                Text(AppCopy.reinstatement)
                    .font(.footnote)
            }
            Circle()
                .fill(.red)
                .frame(width: 16, height: 16)
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(elapsed(at: context.date))
                    .font(.title2.monospacedDigit())
            }
            ScrollView {
                Text(coordinator.liveText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isInterrupted {
                Text(AppCopy.pausedLabel)
                    .foregroundStyle(.secondary)
                Button(AppCopy.resumeButton) {
                    Task { @MainActor in coordinator.send(.tapResume) }
                }
            } else {
                Text(AppCopy.recordingLabel)
                    .foregroundStyle(.secondary)
            }
            if coordinator.lengthWarning {
                Text(AppCopy.lengthWarning)
                    .font(.footnote)
                    .padding(8)
                    .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
            Button(AppCopy.stopButton) {
                Task { @MainActor in coordinator.send(.tapStop) }
            }
        }
        .padding()
        .onAppear {
            loadAnsweringText()
        }
    }

    private func loadAnsweringText() {
        guard let id = coordinator.state.answering else { return }
        var descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let question = try? modelContext.fetch(descriptor).first {
            answeringText = QuestionText.display(question)
        }
    }

    private func elapsed(at now: Date) -> String {
        let total = Int(now.timeIntervalSince(startedAt))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
