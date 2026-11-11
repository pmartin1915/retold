import SwiftData
import SwiftUI

/// The episode page (R7b section 7.5): confirmed facts, open questions, and the recordings with
/// their verbatim transcripts. Every fact is read through EpisodeFacts.
struct EpisodeView: View {
    let episode: Episode

    @Environment(AudioPlayback.self) private var playback

    var body: some View {
        let facts = EpisodeFacts(episode: episode)
        List {
            // comeup run 2: the full title wraps here; the inline nav title may truncate.
            Section {
                Text(facts.title ?? AppCopy.untitled)
                    .font(.title2.bold())
                    .fontDesign(DesignTokens.wordsFontDesign)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("storyTitle")
                if hasFacts(facts) {
                    factRows(facts)
                }
            }
            // The user's own voice and words come before the questions (screenshot 04-story had
            // them below the fold under five offers).
            Section(AppCopy.recordingsHeader) {
                ForEach(sortedCaptures) { capture in
                    captureBlock(capture)
                }
            }
            // comeup run 2, V5 (Perry's pick): the questions fold into one row under the recordings.
            let offers = QuestionEngine.queue(for: EpisodeState(episode: episode))
            if !offers.isEmpty {
                Section {
                    DisclosureGroup("\(AppCopy.questionsHeader) (\(offers.count))") {
                        ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
                            OfferRow(offer: offer, target: .episode(episode))
                        }
                    }
                }
            }
        }
        // The title stays the navigation title (back buttons and VoiceOver use it), but the bar
        // shows nothing: the wrapping header above is the one visible title (comeup run 3, C11).
        .navigationTitle(facts.title ?? AppCopy.untitled)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
    }

    private var sortedCaptures: [Capture] {
        episode.captures.sorted { (a: Capture, b: Capture) -> Bool in
            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
        }
    }

    private func hasFacts(_ facts: EpisodeFacts) -> Bool {
        facts.period != nil || facts.whenDisplay != nil || facts.place != nil
            || !facts.people.isEmpty || !facts.details.isEmpty
    }

    @ViewBuilder
    private func factRows(_ facts: EpisodeFacts) -> some View {
        if let period = facts.period {
            LabeledContent(AppCopy.periodHeader, value: period.title)
        }
        if let when = facts.whenDisplay {
            LabeledContent(AppCopy.whenHeader, value: when)
        }
        // comeup run 3 (C10): a place or a person says which it is before anyone taps it.
        if let ref = facts.place, let place = episode.place {
            NavigationLink(destination: PlaceView(place: place)) {
                Label(ref.name, systemImage: "mappin.and.ellipse")
            }
        }
        ForEach(facts.people, id: \.id) { ref in
            if let person = episode.people.first(where: { $0.id == ref.id }) {
                NavigationLink(destination: PersonView(person: person)) {
                    Label(ref.name, systemImage: "person")
                }
            }
        }
        ForEach(Array(facts.details.enumerated()), id: \.offset) { _, text in
            Label {
                Text("\u{201C}\(text)\u{201D}")
                    .italic()
                    .fontDesign(DesignTokens.wordsFontDesign)
            } icon: {
                Image(systemName: "quote.opening")
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func captureBlock(_ capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            Text("\(capture.createdAt.formatted(date: .abbreviated, time: .shortened)) \u{00B7} \(ExportManifest.formatClock(capture.duration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if playback.canPlay(capture.id) {
                PlayerRow(captureID: capture.id, duration: capture.duration)
            } else {
                Text(AppCopy.audioMissing)
                    .foregroundStyle(.secondary)
            }
            transcript(capture)
        }
    }

    @ViewBuilder
    private func transcript(_ capture: Capture) -> some View {
        switch CaptureTranscriptState.of(status: capture.transcriptionStatus, segments: capture.transcript) {
        case .transcribing:
            Text(AppCopy.transcribingLabel)
                .foregroundStyle(.secondary)
        case .none:
            Text(AppCopy.noTranscript)
                .foregroundStyle(.secondary)
        case .segments(let segments):
            // comeup run 3 (C9): each line is tap-to-seek, so its time carries the accent as the cue;
            // the words are primary text in the serif face, leading-aligned under each other.
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Button {
                    playback.play(capture.id, from: segment.start)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.m) {
                        Text(ExportManifest.formatClock(segment.start))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.tint)
                        Text(segment.text)
                            .fontDesign(DesignTokens.wordsFontDesign)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(ExportManifest.formatClock(segment.start)), \(segment.text)")
                .accessibilityHint(AppCopy.seekHint)
            }
        }
    }
}

/// comeup run 2: the play button, scrubber and clock. Only this view reads `currentTime`, so the
/// 4 Hz playback tick redraws one row, not the whole story page. At accessibility text sizes the
/// clock moves under the scrubber so the slider keeps its width.
private struct PlayerRow: View {
    let captureID: UUID
    let duration: TimeInterval

    @Environment(AudioPlayback.self) private var playback
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLoaded = playback.captureID == captureID
        let clock = "\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(duration))"
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    PlayPauseButton(captureID: captureID)
                    slider(isLoaded: isLoaded, clock: clock)
                }
                clockText(clock)
            } else {
                HStack {
                    PlayPauseButton(captureID: captureID)
                    slider(isLoaded: isLoaded, clock: clock)
                    clockText(clock)
                }
            }
            if playback.failedCaptureID == captureID {
                Text(AppCopy.playbackFailed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
    }

    private func slider(isLoaded: Bool, clock: String) -> some View {
        Slider(
            value: Binding(
                get: { isLoaded ? playback.currentTime : 0 },
                set: { value in
                    if playback.captureID == captureID {
                        playback.seek(to: value)
                    } else {
                        playback.play(captureID, from: value)
                    }
                }
            ),
            in: 0...max(duration, 1)
        )
        .disabled(duration <= 0)
        .accessibilityLabel(AppCopy.playbackPosition)
        .accessibilityValue(clock)
    }

    private func clockText(_ clock: String) -> some View {
        Text(clock)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
