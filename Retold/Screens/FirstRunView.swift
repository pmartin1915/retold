import SwiftUI

/// R6b first run: the microphone grant plus asset prefetch (R7 replaces this screen).
struct FirstRunView: View {
    let engine: LiveCaptureEngine
    let prefetch: AssetPrefetch
    let onDone: (MicrophonePermission) -> Void
    @State private var denied = false
    /// Single-flight: a second tap while the system prompt is up must not start a second request.
    @State private var requesting = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            Text(AppCopy.micPrompt)
                .multilineTextAlignment(.center)
            if denied {
                Text(AppCopy.micDenied)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if denied {
                Button(AppCopy.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            } else {
                Button(AppCopy.micAllow) {
                    guard !requesting else { return }
                    requesting = true
                    Task { @MainActor in
                        defer { requesting = false }
                        finish(await engine.requestMicrophonePermission())
                    }
                }
                .disabled(requesting)
            }
        }
        .padding()
        // Back from Settings with the microphone now on: carry on without another tap.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, denied, !requesting else { return }
            requesting = true
            Task { @MainActor in
                defer { requesting = false }
                finish(await engine.microphonePermission())
            }
        }
    }

    private func finish(_ permission: MicrophonePermission) {
        guard permission != .denied else {
            denied = true
            return
        }
        Task { await prefetch.run() }   // never blocks the UI
        onDone(permission)
    }
}
