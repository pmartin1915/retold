import SwiftUI

/// R6b home: the week-0 placeholder plus the record button (R7 replaces this screen).
struct HomeView: View {
    let coordinator: CaptureCoordinator

    var body: some View {
        VStack(spacing: 12) {
            Text(AppCopy.homeTitle)
                .font(.largeTitle.bold())
            Text(AppCopy.homePlaceholder)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(AppCopy.recordButton) {
                Task { @MainActor in await coordinator.startCapture(answering: nil) }
            }
        }
        .padding()
    }
}
