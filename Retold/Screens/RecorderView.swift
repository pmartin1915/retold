import Foundation
import SwiftData
import SwiftUI

/// R6b recorder: status, elapsed time, live text, Stop, and Resume while interrupted
/// (comeup run 2: one primary action in thumb reach; comeup run 3: recording capsule, the live
/// words as the screen's body, and StoryCue's record ring as Stop).
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

    /// One value per visible phase, so phase changes animate the status capsule.
    private var phaseKey: Int {
        if isStarting { return 0 }
        if isRecording { return 1 }
        if isInterrupted { return 2 }
        if isStopping { return 3 }
        return 4
    }

    private var ringGlyph: RecordRing.Glyph {
        if isStarting { return .dot }
        if isStopping { return .spinner }
        return .square
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            if coordinator.state.answering != nil {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(AppCopy.answeringLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let answeringText {
                        Text(answeringText)
                            .font(.title3)
                            .fontDesign(DesignTokens.wordsFontDesign)
                    }
                    Text(AppCopy.reinstatement)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            // comeup run 3 (F2, Perry's pick; StoryCue's recording pill): the state in words on a
            // fill that says "recording" at a glance, then the clock as the headline.
            statusCapsule
            TimelineView(.periodic(from: tickAnchor, by: 1)) { context in
                Text(elapsed(at: context.date))
                    .font(.largeTitle.monospacedDigit().weight(.semibold))
            }
            // comeup run 3: the live words fill the middle of the screen; only this child reads them.
            LiveTranscript(coordinator: coordinator)
                .layoutPriority(1)
            if coordinator.lengthWarning {
                Text(AppCopy.lengthWarning)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.warningInk)
                    .padding(DesignTokens.Spacing.s)
                    .frame(maxWidth: .infinity)
                    .background(DesignTokens.warningFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.top, DesignTokens.Spacing.s)
        .animation(reduceMotion ? nil : DesignTokens.Motion.fade, value: phaseKey)
        .animation(reduceMotion ? nil : DesignTokens.Motion.fade, value: coordinator.lengthWarning)
        // The ring is the screen's one primary action, in thumb reach; Resume joins it while paused.
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
            // Stop is always available; while interrupted it still ends and saves the capture.
            RecordRing(glyph: ringGlyph, label: AppCopy.stopButton) {
                Task { @MainActor in coordinator.send(.tapStop) }
            }
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

    /// Recording: white on the recording red with a breathing dot. Other phases: neutral, in words.
    @ViewBuilder
    private var statusCapsule: some View {
        if isRecording {
            HStack(spacing: DesignTokens.Spacing.s) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .symbolEffect(.breathe.plain, options: .repeating, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                Text(AppCopy.recordingLabel)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.m)
            .padding(.vertical, DesignTokens.Spacing.s)
            .background(DesignTokens.recordingFill, in: Capsule())
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: DesignTokens.Spacing.s) {
                if isStarting || isStopping {
                    // Engine spin-up or file finalizing: no audio is being captured right now.
                    ProgressView()
                        .controlSize(.small)
                } else if isInterrupted {
                    Image(systemName: "pause.fill")
                        .accessibilityHidden(true)
                }
                Text(statusWord)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignTokens.Spacing.m)
            .padding(.vertical, DesignTokens.Spacing.s)
            .background(.fill.tertiary, in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }

    private var statusWord: String {
        if isInterrupted { return AppCopy.pausedLabel }
        if isStarting { return AppCopy.startingLabel }
        if isStopping { return AppCopy.savingLabel }
        return AppCopy.recordingLabel
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

/// The live words while recording (comeup run 3, findings C1/C19). Only this view reads the live
/// text, so a volatile result redraws it and not the clock or the controls. Settled words are
/// primary; the tentative tail, which the recognizer may still revise, is secondary. The scroll
/// stays pinned to the newest words as the text grows.
private struct LiveTranscript: View {
    let coordinator: CaptureCoordinator

    var body: some View {
        let settled = coordinator.liveFinalText
        let tentative = coordinator.liveVolatileText
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                if settled.isEmpty && tentative.isEmpty {
                    Text(AppCopy.liveTextPlaceholder)
                        .foregroundStyle(.secondary)
                }
                if !settled.isEmpty {
                    Text(settled)
                }
                if !tentative.isEmpty {
                    Text(tentative)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.title3)
            .fontDesign(DesignTokens.wordsFontDesign)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.l)
        }
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .frame(maxHeight: .infinity)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    }
}
