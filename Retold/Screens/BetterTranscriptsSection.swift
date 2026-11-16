import SwiftUI

/// Settings: download or delete the Whisper model (docs/WHISPER-PASS-SPEC.md section 5).
struct BetterTranscriptsSection: View {
    @Environment(CaptureCoordinator.self) private var coordinator
    @State private var deleting = false
    private let manager = WhisperModelManager.shared

    var body: some View {
        Section {
            switch manager.state {
            case .absent:
                Button(AppCopy.whisperDownloadButton) { manager.requestDownload() }
            case .waitingForWiFi:
                Text(AppCopy.whisperWaitingForWiFi)
            case .downloading(let percent):
                HStack {
                    ProgressView()
                    Text(AppCopy.whisperDownloading(percent))
                }
            case .preparing:
                HStack {
                    ProgressView()
                    Text(AppCopy.whisperPreparing)
                }
            case .ready(let megabytes):
                Text(AppCopy.whisperReady(megabytes))
                Button(AppCopy.whisperDelete, role: .destructive) {
                    deleting = true
                    Task {
                        await manager.delete(waitingFor: coordinator)
                        deleting = false
                    }
                }
                .disabled(deleting)
            case .failed(let detail):
                Text(AppCopy.whisperFailed + detail)
                Button(AppCopy.tryAgain) { manager.requestDownload() }
            }
        } header: {
            Text(AppCopy.betterTranscriptsTitle)
        } footer: {
            Text(AppCopy.whisperFootnote)
        }
    }
}
