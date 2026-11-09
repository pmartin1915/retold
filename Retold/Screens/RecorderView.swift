import Foundation
import SwiftData
import SwiftUI

/// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
/// (comeup run 2: house-style pass; one primary action in thumb reach).
struct RecorderView: View {
    let coordinator: CaptureCoordinator
    /// Anchor for the once-a-second redraw only; the displayed time is accumulated audio time.
    @State private var tickAnchor = Date()
    /// Seconds recorded in earlier .recording stretches (an interruption closes one).
    @State private var accumulated: TimeInterval = 0
    /// When the current .recording stretch began; nil while starting, interrupted or stopping.
    @State private var runningSince: Date?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        VStack(spacing: DesignTokens.Spacing.l) {
            if coordinator.state.answering != nil {
                Text(AppCopy.answeringLabel)
                    .foregroundStyle(.secondary)
                if let answeringText {
                    Text(answeringText)
                        .font(.headline)
                }
                Text(AppCopy.reinstatement)
                    .font(.footnote)
            }
            // comeup run 2: the live state is the screen's headline, not a 16 pt dot.
            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: DesignTokens.recordingDotSize))
                    .foregroundStyle(isRecording ? DesignTokens.recordingDot : Color.secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRecording && !reduceMotion)
                    .accessibilityHidden(true)
                TimelineView(.periodic(from: tickAnchor, by: 1)) { context in
                    Text(elapsed(at: context.date))
                        .font(.largeTitle.monospacedDigit().weight(.semibold))
                }
            }
            statusLine
            ScrollView {
                Text(coordinator.liveText)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            if coordinator.lengthWarning {
                Text(AppCopy.lengthWarning)
                    .font(.footnote)
                    .padding(DesignTokens.Spacing.s)
                    .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
            }
        }
        .padding()
        // Stop (or Resume) is the screen's one primary action, full width in thumb reach.
        .primaryActionBar {
            if isInterrupted {
                Button {
                    Task { @MainActor in coordinator.send(.tapResume) }
                } label: {
                    Label(AppCopy.resumeButton, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()
            }
            // Stop is always available; while interrupted it is secondary to Resume but still ends
            // and saves the capture.
            Button {
                Task { @MainActor in coordinator.send(.tapStop) }
            } label: {
                Label(AppCopy.stopButton, systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .modifier(StopButtonStyle(primary: !isInterrupted))
            .disabled(isStopping || isStarting)
        }
        .onAppear {
            loadAnsweringText()
            syncClock()
        }
        .onChange(of: coordinator.state.phase) { _, _ in
            syncClock()
            // A sighted user sees the label change; VoiceOver users need it spoken.
            if isInterrupted {
                AccessibilityNotification.Announcement(AppCopy.pausedLabel).post()
            } else if isStopping {
                AccessibilityNotification.Announcement(AppCopy.savingLabel).post()
            }
        }
        .onChange(of: coordinator.lengthWarning) { _, warning in
            if warning { AccessibilityNotification.Announcement(AppCopy.lengthWarning).post() }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if isInterrupted {
            Text(AppCopy.pausedLabel)
                .foregroundStyle(.secondary)
        } else if isStarting {
            // Engine spin-up: no audio is being captured yet, so do not say "Recording".
            HStack(spacing: DesignTokens.Spacing.s) {
                ProgressView()
                Text(AppCopy.startingLabel)
                    .foregroundStyle(.secondary)
            }
        } else if isStopping {
            // The engine is finalizing the file: say so, instead of looking like it still records.
            HStack(spacing: DesignTokens.Spacing.s) {
                ProgressView()
                Text(AppCopy.savingLabel)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(AppCopy.recordingLabel)
                .foregroundStyle(.secondary)
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

/// Stop is the primary action while recording, and a secondary (bordered, large) one under Resume
/// while interrupted.
private struct StopButtonStyle: ViewModifier {
    let primary: Bool

    func body(content: Content) -> some View {
        if primary {
            content.primaryAction()
        } else {
            content
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}
