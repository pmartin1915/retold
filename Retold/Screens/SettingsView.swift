import SwiftData
import SwiftUI

enum SettingsKeys {
    static let suggestionsOn = "retold.suggestionsOn"
}

struct SettingsView: View {
    let files: CaptureFiles

    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
    @Environment(\.modelContext) private var modelContext

    private enum ExportState {
        case idle
        case preparing
        case ready(URL)
        case failed
    }

    @State private var exportState = ExportState.idle

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(AppCopy.suggestionsToggle, isOn: $suggestionsOn)
                    Text(AppCopy.suggestionsFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    switch exportState {
                    case .idle, .failed:
                        Button(AppCopy.exportButton) {
                            startExport()
                        }
                    case .preparing:
                        HStack {
                            ProgressView()
                            Text(AppCopy.preparingExport)
                        }
                    case .ready(let url):
                        ShareLink(item: url) {
                            Text(AppCopy.shareExport)
                        }
                    }
                    if case .failed = exportState {
                        Text(AppCopy.exportFailed)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(AppCopy.exportNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppCopy.settingsTitle)
        }
    }

    /// Builds the manifest on the main actor, then zips off it. Export is never gated.
    private func startExport() {
        exportState = .preparing
        let manifest: ExportManifest
        do {
            let periods = try modelContext.fetch(FetchDescriptor<Period>())
            let episodes = try modelContext.fetch(FetchDescriptor<Episode>())
            let captures = try modelContext.fetch(FetchDescriptor<Capture>())
            let questions = try modelContext.fetch(FetchDescriptor<Question>())
            let library = ExportLibrary(
                periods: periods, episodes: episodes, captures: captures, questions: questions)
            manifest = ExportManifest.build(library, exportedAt: Date(), timeZone: .current)
        } catch {
            exportState = .failed
            return
        }
        let audioDirectory = files.audioDirectory
        let workDirectory = ExportArchiver.defaultWorkDirectory
        let name = ExportArchiver.exportName(at: Date())
        Task { @MainActor in
            do {
                let url = try await Task.detached {
                    try ExportArchiver.makeArchive(
                        manifest, audioDirectory: audioDirectory, workDirectory: workDirectory, name: name)
                }.value
                exportState = .ready(url)
            } catch {
                exportState = .failed
            }
        }
    }
}
