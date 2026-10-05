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
            if hasFacts(facts) {
                Section {
                    factRows(facts)
                }
            }
            OfferSection(
                offers: QuestionEngine.queue(for: EpisodeState(episode: episode)),
                target: .episode(episode)
            )
            Section(AppCopy.recordingsHeader) {
                ForEach(sortedCaptures) { capture in
                    captureBlock(capture)
                }
            }
        }
        .navigationTitle(facts.title ?? AppCopy.untitled)
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
        if let ref = facts.place, let place = episode.place {
            NavigationLink(ref.name, destination: PlaceView(place: place))
        }
        ForEach(facts.people, id: \.id) { ref in
            if let person = episode.people.first(where: { $0.id == ref.id }) {
                NavigationLink(ref.name, destination: PersonView(person: person))
            }
        }
        ForEach(Array(facts.details.enumerated()), id: \.offset) { _, text in
            Text("\u{201C}\(text)\u{201D}")
        }
    }

    @ViewBuilder
    private func captureBlock(_ capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(capture.createdAt.formatted(date: .abbreviated, time: .shortened)) \u{00B7} \(ExportManifest.formatClock(capture.duration))")
                .font(.subheadline)
            if playback.canPlay(capture.id) {
                playerRow(capture)
            } else {
                Text(AppCopy.audioMissing)
                    .foregroundStyle(.secondary)
            }
            transcript(capture)
        }
    }

    private func playerRow(_ capture: Capture) -> some View {
        let isLoaded = playback.captureID == capture.id
        return HStack {
            PlayPauseButton(captureID: capture.id)
            Slider(
                value: Binding(
                    get: { isLoaded ? playback.currentTime : 0 },
                    set: { value in
                        if playback.captureID == capture.id {
                            playback.seek(to: value)
                        } else {
                            playback.play(capture.id, from: value)
                        }
                    }
                ),
                in: 0...max(capture.duration, 1)
            )
            .disabled(capture.duration <= 0)
            Text("\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(capture.duration))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
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
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Button {
                    playback.play(capture.id, from: segment.start)
                } label: {
                    Text("\(ExportManifest.formatClock(segment.start))  \(segment.text)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
