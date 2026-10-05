import SwiftData
import SwiftUI
import UIKit

@main
struct RetoldApp: App {
    @State private var services: LiveCapture.LiveCaptureServices?
    @State private var startupFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if startupFailed {
                    Text(AppCopy.startupFailed)
                        .padding()
                } else if let services {
                    RootView(services: services)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard services == nil, !startupFailed else { return }
                do {
                    services = try LiveCapture.makeCoordinator()
                } catch {
                    startupFailed = true
                }
            }
        }
    }
}

/// Routes between first run, recorder and home, and turns scene / protected-data signals
/// into coordinator events.
private struct RootView: View {
    let services: LiveCapture.LiveCaptureServices
    @Environment(\.scenePhase) private var scenePhase
    @State private var autoPresentID: UUID?
    @State private var playback: AudioPlayback

    private var coordinator: CaptureCoordinator { services.coordinator }

    init(services: LiveCapture.LiveCaptureServices) {
        self.services = services
        _playback = State(initialValue: AudioPlayback(files: services.coordinator.files))
    }

    var body: some View {
        Group {
            if coordinator.state.permission == .undetermined {
                FirstRunView(engine: services.engine, prefetch: services.prefetch) { permission in
                    coordinator.send(.permissionChanged(permission))
                }
            } else {
                switch coordinator.state.phase {
                case .starting, .recording, .interrupted, .stopping:
                    RecorderView(coordinator: coordinator)
                case .idle, .blocked, .aborting:
                    HomeView(coordinator: coordinator, autoPresentID: $autoPresentID)
                }
            }
        }
        .environment(playback)
        .environment(coordinator)
        .modelContainer(services.container)
        .task {
            // The export zip holds the whole library unencrypted in tmp: clear any leftover.
            ExportArchiver.sweep(workDirectory: ExportArchiver.defaultWorkDirectory)
            await coordinator.run()
        }
        .onChange(of: coordinator.state.phase) { oldPhase, newPhase in
            if case .stopping(let id, _) = oldPhase, case .idle = newPhase {
                autoPresentID = id
            }
            // Playback yields to the recorder (covers the Control and the Action button). The
            // recorder's own setCategory supersedes playback, so the session is not deactivated.
            switch newPhase {
            case .idle, .blocked:
                break
            default:
                playback.stop(deactivateSession: false)
            }
        }
        // initial: true -- RootView appears only after the services exist, when the scene is already
        // active; without it a cold launch from the Control never drains the launch inbox.
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            Task { @MainActor in
                switch newPhase {
                case .active:
                    coordinator.send(.sceneDidBecomeActive)
                    await coordinator.drainLaunchInbox()
                case .inactive:
                    coordinator.send(.sceneWillResignActive)
                case .background:
                    coordinator.send(.sceneDidEnterBackground)
                @unknown default:
                    break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            Task { @MainActor in coordinator.send(.protectedDataWillBecomeUnavailable) }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            Task { @MainActor in coordinator.send(.protectedDataDidBecomeAvailable) }
        }
    }
}
