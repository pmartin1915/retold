import SwiftUI

/// R6b first run: the microphone grant plus asset prefetch (R7 replaces this screen).
struct FirstRunView: View {
    let engine: LiveCaptureEngine
    let prefetch: AssetPrefetch
    let onDone: (MicrophonePermission) -> Void
    @State private var denied = false

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
            Button(AppCopy.micAllow) {
                Task { @MainActor in
                    let permission = await engine.requestMicrophonePermission()
                    guard permission != .denied else {
                        denied = true
                        return
                    }
                    Task { await prefetch.run() }   // never blocks the UI
                    onDone(permission)
                }
            }
        }
        .padding()
    }
}
