import Foundation
import SwiftData
import SwiftUI

/// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
/// (R7 replaces this screen; no design pass).
struct RecorderView: View {
    let coordinator: CaptureCoordinator
    /// Anchor for the once-a-second redraw only; the displayed time is accumulated audio time.
    @State private var tickAnchor = Date()
    /// Seconds recorded in earlier .recording stretches (an interruption closes one).
    @State private var accumulated: TimeInterval = 0
    /// When the current .recording stretch began; nil while starting, interrupted or stopping.
    @State private var runningSince: Date?
    @Environment(\.modelContext) private var modelContext
    /// R7b: the question this capture answers, fetched once on appear. Hidden when not found.
    @State private var answeringText: String?

    private var isInterrupted: Bool {
        if case .interrupted = coordinator.state.phase { return true }
        return false
    }

    private var isRecording: Bool {
        if case .recording = coordinator.state.phase { return true }
        return false
    }

    private var isStarting: Bool {
        if case .starting = coordinator.state.phase { return true }
        return false
    }

    private var isStopping: Bool {
        if case .stopping = coordinator.state.phase { return true }
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
            TimelineView(.periodic(from: tickAnchor, by: 1)) { context in
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
            } else if isStarting {
                // Engine spin-up: no audio is being captured yet, so do not say "Recording".
                HStack(spacing: 8) {
                    ProgressView()
                    Text(AppCopy.startingLabel)
                        .foregroundStyle(.secondary)
                }
            } else if isStopping {
                // The engine is finalizing the file: say so, instead of looking like it still records.
                HStack(spacing: 8) {
                    ProgressView()
                    Text(AppCopy.savingLabel)
                        .foregroundStyle(.secondary)
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
            .disabled(isStopping || isStarting)
        }
        .padding()
        .onAppear {
            loadAnsweringText()
            syncClock()
        }
        .onChange(of: coordinator.state.phase) { _, _ in
            syncClock()
        }
    }

    /// Counts time only while the phase is .recording, so the clock matches the saved file.
    private func syncClock() {
        if isRecording {
            if runningSince == nil { runningSince = Date() }
        } else if let since = runningSince {
            accumulated += Date().timeIntervalSince(since)
            runningSince = nil
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
        let live = runningSince.map { now.timeIntervalSince($0) } ?? 0
        let total = Int(accumulated + live)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
