import SwiftData
import SwiftUI

struct HomeView: View {
    let coordinator: CaptureCoordinator
    @Binding var autoPresentID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Capture> { $0.episode == nil },
        sort: [SortDescriptor(\Capture.createdAt, order: .reverse)]
    ) private var unfiledCaptures: [Capture]
    @Query(sort: \Episode.createdAt, order: .reverse) private var filedEpisodes: [Episode]

    @State private var selectedCapture: Capture?
    @State private var showingSettings = false
    @State private var outcomes: [UUID: FilingOutcome] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section(AppCopy.unfiledHeader) {
                    ForEach(unfiledCaptures) { capture in
                        unfiledRow(capture)
                    }
                }
                Section(AppCopy.filedHeader) {
                    ForEach(filedEpisodes) { episode in
                        Text(episode.title.value)
                    }
                }
                Section {
                    Button(AppCopy.recordButton) {
                        Task { @MainActor in
                            await coordinator.startCapture(answering: nil)
                        }
                    }
                }
            }
            .navigationTitle(AppCopy.homeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $selectedCapture) { capture in
            ConfirmView(
                capture: capture,
                row: ConfirmDraft.unfiledRow(
                    status: capture.transcriptionStatus,
                    transcript: capture.completedTranscript
                ),
                cachedOutcome: outcomes[capture.id]
            ) { outcome in
                outcomes[capture.id] = outcome
            }
        }
        .onAppear {
            try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)
            handleAutoPresent()
        }
        .onChange(of: autoPresentID) { _, _ in
            handleAutoPresent()
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
            captureRow(capture, detail: AppCopy.transcribingLabel)
        case .ready(let excerpt):
            Button {
                selectedCapture = capture
            } label: {
                captureRow(capture, detail: excerpt)
            }
            .buttonStyle(.plain)
        case .noTranscript:
            Button {
                selectedCapture = capture
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

    private func handleAutoPresent() {
        guard let id = autoPresentID else { return }
        defer { autoPresentID = nil }
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
            selectedCapture = capture
        case .transcribing:
            break
        }
    }
}
