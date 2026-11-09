import SwiftData
import SwiftUI

struct HomeView: View {
    let coordinator: CaptureCoordinator
    @Binding var autoPresentID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AudioPlayback.self) private var playback
    @Environment(\.openURL) private var openURL
    @Query(
        filter: #Predicate<Capture> { $0.episode == nil },
        sort: [SortDescriptor(\Capture.createdAt, order: .reverse)]
    ) private var unfiledCaptures: [Capture]
    @Query(sort: \Period.sortOrder) private var periods: [Period]
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]

    @State private var selectedCapture: Capture?
    @State private var selectedAnsweredPeriodID: UUID?
    @State private var showingSettings = false
    @State private var outcomes: [UUID: FilingOutcome] = [:]
    // The id, never a Capture: reading a property of a deleted SwiftData model can trap.
    @State private var pendingDeleteID: UUID?
    @State private var deleteFailed = false
    @State private var micBlocked = false

    private var sections: [TimelineSection] {
        Timeline.sections(
            periods: periods.map { PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder) },
            episodes: episodes.map { TimelineEpisode(id: $0.id, periodID: $0.period?.id, createdAt: $0.createdAt) }
        )
    }

    var body: some View {
        let periodsByID = Dictionary(periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let episodesByID = Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            List {
                if !unfiledCaptures.isEmpty {
                    Section(AppCopy.unfiledHeader) {
                        ForEach(unfiledCaptures) { capture in
                            unfiledRow(capture)
                                // Not a full swipe: a full swipe must never delete without the dialog.
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(AppCopy.deleteAction, role: .destructive) { pendingDeleteID = capture.id }
                                }
                        }
                    }
                }
                // comeup run 2: an empty library says what will appear here (house style rule 12).
                // Periods stay below it: an empty period's page is where its opener lives.
                if unfiledCaptures.isEmpty && episodes.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label(AppCopy.homeEmptyTitle, systemImage: "waveform")
                        } description: {
                            Text(AppCopy.homeEmptyMessage)
                        }
                    }
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    Section {
                        if let ref = section.period {
                            if let period = periodsByID[ref.id] {
                                NavigationLink(destination: PeriodView(period: period)) {
                                    Text(ref.title)
                                        .font(.headline)
                                }
                            }
                        } else {
                            Text(AppCopy.noPeriod)
                                .font(.headline)
                        }
                        ForEach(section.episodeIDs, id: \.self) { id in
                            if let episode = episodesByID[id] {
                                EpisodeRow(episode: episode)
                            }
                        }
                    }
                }
                // comeup run 2: browse links come after the user's own stories, not above them.
                Section(AppCopy.browseHeader) {
                    NavigationLink(AppCopy.peopleHeader, destination: PeopleView())
                    NavigationLink(AppCopy.placesTitle, destination: PlacesView())
                    NavigationLink(AppCopy.themesTitle, destination: ThemesView())
                    NavigationLink(AppCopy.periodsTitle, destination: PeriodsView())
                    NavigationLink(AppCopy.setAsideTitle, destination: SetAsideView())
                }
            }
            // comeup run 2: the app's one primary action is a filled accent button in thumb reach,
            // not a list row with the same weight as every other row.
            .primaryActionBar {
                Button(action: startRecording) {
                    Label(AppCopy.recordButton, systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()
            }
            .navigationTitle(AppCopy.homeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel(AppCopy.settingsTitle)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(files: coordinator.files)
        }
        .sheet(item: $selectedCapture) { capture in
            ConfirmView(
                capture: capture,
                row: ConfirmDraft.unfiledRow(
                    status: capture.transcriptionStatus,
                    transcript: capture.completedTranscript
                ),
                cachedOutcome: outcomes[capture.id],
                answeredPeriodID: selectedAnsweredPeriodID
            ) { outcome in
                outcomes[capture.id] = outcome
            }
        }
        .confirmationDialog(
            AppCopy.deleteRecordingTitle,
            isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeleteID
        ) { id in
            Button(AppCopy.deleteRecordingConfirm, role: .destructive) { deleteCapture(id) }
        } message: { _ in
            Text(AppCopy.deleteRecordingMessage)
        }
        .alert(AppCopy.deleteFailed, isPresented: $deleteFailed) {
            Button(AppCopy.okButton, role: .cancel) {}
        }
        .alert(AppCopy.startFailedTitle, isPresented: Binding(
            get: { coordinator.startFailure != nil },
            set: { if !$0 { coordinator.clearStartFailure() } }
        )) {
            Button(AppCopy.okButton, role: .cancel) {}
        } message: {
            Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? ""))
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
        .onAppear {
            // Order matters: seed periods, then attach answers, then auto-present. Home is created
            // fresh after Stop, so autoPresentID is already set here; an episode answer must attach
            // before auto-present, or it would open a confirm sheet it should not get.
            try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)
            _ = try? AnswerAttacher.attachPending(in: modelContext)
            handleAutoPresent()
        }
        .onChange(of: autoPresentID) { _, _ in
            handleAutoPresent()
        }
        .onChange(of: coordinator.lastImport) { _, _ in
            _ = try? AnswerAttacher.attachPending(in: modelContext)
        }
        // The file pass completes audio-only captures without setting lastImport.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                _ = try? AnswerAttacher.attachPending(in: modelContext)
            }
        }
    }

    private func startRecording() {
        // Stop playback (deactivating) before the capture starts, while the phase is .idle.
        playback.stop()
        Task { @MainActor in
            await coordinator.startCapture(answering: nil)
            // A denied microphone used to do nothing visible.
            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
                micBlocked = true
            }
        }
    }

    @ViewBuilder
    private func unfiledRow(_ capture: Capture) -> some View {
        let state = ConfirmDraft.unfiledRow(
            status: capture.transcriptionStatus,
            transcript: capture.completedTranscript
        )
        switch state {
        case .transcribing:
            // Tappable: a recording whose transcript never arrives (no on-device speech for this
            // locale) must still be fileable with a typed title. ConfirmView handles this row.
            Button {
                present(capture)
            } label: {
                captureRow(capture, detail: AppCopy.transcribingLabel)
            }
            .buttonStyle(.plain)
        case .ready(let excerpt):
            Button {
                present(capture)
            } label: {
                captureRow(capture, detail: excerpt)
            }
            .buttonStyle(.plain)
        case .noTranscript:
            Button {
                present(capture)
            } label: {
                captureRow(capture, detail: AppCopy.noTranscriptLabel)
            }
            .buttonStyle(.plain)
        }
    }

    private func captureRow(_ capture: Capture, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
            Text(detail)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @MainActor
    private func deleteCapture(_ id: UUID) {
        do {
            try CaptureDeleter.delete(
                captureID: id,
                activeCaptureID: coordinator.activeCaptureID,
                files: coordinator.files,
                in: modelContext.container
            )
            outcomes[id] = nil
        } catch CaptureDeleteError.filed {
            // Attached since the swipe: the row has already left Unfiled.
        } catch {
            deleteFailed = true
        }
    }

    /// Computes the answered period once per presentation, never in the sheet closure.
    private func present(_ capture: Capture) {
        selectedAnsweredPeriodID = AnswerAttacher.answeredPeriodID(for: capture, in: modelContext)
        selectedCapture = capture
    }

    private func handleAutoPresent() {
        guard let id = autoPresentID else { return }
        defer { autoPresentID = nil }
        // An answer to an episode's question attaches first, so it never opens a confirm sheet.
        _ = try? AnswerAttacher.attachPending(in: modelContext)
        let wantedID = id
        var descriptor = FetchDescriptor<Capture>(
            predicate: #Predicate { $0.id == wantedID }
        )
        descriptor.fetchLimit = 1
        guard let captures = try? modelContext.fetch(descriptor),
              let capture = captures.first,
              capture.episode == nil
        else { return }

        switch ConfirmDraft.unfiledRow(
            status: capture.transcriptionStatus,
            transcript: capture.completedTranscript
        ) {
        case .ready, .noTranscript:
            present(capture)
        case .transcribing:
            break
        }
    }
}

/// A button that plays or pauses one capture. Disabled when its audio file is missing.
struct PlayPauseButton: View {
    let captureID: UUID

    @Environment(AudioPlayback.self) private var playback

    var body: some View {
        let isThisPlaying = playback.captureID == captureID && playback.isPlaying
        Button {
            if isThisPlaying {
                playback.pause()
            } else {
                playback.play(captureID)
            }
        } label: {
            Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!playback.canPlay(captureID))
        .accessibilityLabel(isThisPlaying ? AppCopy.pauseButton : AppCopy.playButton)
        .sensoryFeedback(.impact(weight: .light), trigger: isThisPlaying)
        // comeup run 2: a failed play is felt, not a dead tap (AudioPlayback announces it once).
        .sensoryFeedback(.error, trigger: playback.failureCount) { _, _ in playback.failedCaptureID == captureID }
    }
}

/// One episode in a list (R7b section 7.2), reused by the period, person and place pages.
struct EpisodeRow: View {
    let episode: Episode

    private var firstCapture: Capture? {
        episode.captures.min { (a: Capture, b: Capture) -> Bool in
            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
        }
    }

    var body: some View {
        let facts = EpisodeFacts(episode: episode)
        NavigationLink(destination: EpisodeView(episode: episode)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(facts.title ?? AppCopy.untitled)
                    // Verbatim user words, the same line the export prints; not a Confirmable.
                    if !episode.excerpt.isEmpty {
                        Text(episode.excerpt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let when = facts.whenDisplay {
                        Text(when)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let capture = firstCapture {
                    PlayPauseButton(captureID: capture.id)
                }
            }
        }
    }
}

extension Collection where Element == Episode {
    /// Newest first, by `(createdAt descending, id.uuidString)`.
    func newestFirst() -> [Episode] {
        sorted { (a: Episode, b: Episode) -> Bool in
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }
}
