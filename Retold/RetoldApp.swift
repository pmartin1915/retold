import SwiftData
import SwiftUI
import UIKit

@main
struct RetoldApp: App {
    @State private var services: LiveCapture.LiveCaptureServices?
    @State private var startupFailed = false
    #if DEBUG
    @MainActor private static var failedFirstStart = false
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if startupFailed {
                    // comeup run 2: a designed error state with one action, not bare text.
                    ContentUnavailableView {
                        Label(AppCopy.startupFailedTitle, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(AppCopy.startupFailed)
                    } actions: {
                        Button(AppCopy.tryAgain) {
                            startupFailed = false
                            startServices()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let services {
                    RootView(services: services)
                } else {
                    LaunchView()
                }
            }
            .task {
                startServices()
            }
        }
    }

    /// Opens storage and the capture services; a failure shows the error state, whose Try again
    /// calls this again.
    @MainActor
    private func startServices() {
        guard services == nil, !startupFailed else { return }
        do {
            #if DEBUG
            // `-RetoldFailFirstStart` (FlowTests only) fails the first open, to exercise Try again.
            if ProcessInfo.processInfo.arguments.contains("-RetoldFailFirstStart"), !Self.failedFirstStart {
                Self.failedFirstStart = true
                throw CocoaError(.fileReadUnknown)
            }
            // `-RetoldDemo` (ScreenshotTests only) launches the seeded mock demo; everything
            // else is production. The Release build compiles only the production line below.
            if DemoMode.isActive {
                services = try DemoMode.makeServices()
            } else {
                services = try LiveCapture.makeCoordinator()
            }
            #else
            services = try LiveCapture.makeCoordinator()
            #endif
        } catch {
            startupFailed = true
        }
    }
}

/// comeup run 2, V3 (Perry's pick; BoardBound BrandedSplash.tsx): the mark and name on the
/// family-line accent while storage opens, instead of a bare spinner. No timed delay: it shows only
/// as long as startServices() takes.
private struct LaunchView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            Image("RetoldMark")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(AppCopy.homeTitle)
                .font(.largeTitle.bold())
            ProgressView()
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Screen { case firstRun, recorder, home }

    private var screen: Screen {
        if coordinator.state.permission == .undetermined { return .firstRun }
        switch coordinator.state.phase {
        case .starting, .recording, .interrupted, .stopping: return .recorder
        case .idle, .blocked, .aborting: return .home
        }
    }

    /// Haptic for a recorder phase change; nil means no feedback.
    static func feedback(from old: RecorderPhase, to new: RecorderPhase) -> SensoryFeedback? {
        switch (old, new) {
        case (_, .recording):
            return .start
        case (.recording, .interrupted):
            return .warning
        case (_, .stopping):
            return .stop
        case (.stopping, .idle):
            return .success
        default:
            return nil
        }
    }

    var body: some View {
        Group {
            if coordinator.state.permission == .undetermined {
                FirstRunView(engine: services.engine, prefetch: services.prefetch) { permission in
                    coordinator.send(.permissionChanged(permission))
                }
                .transition(.opacity)
            } else {
                switch coordinator.state.phase {
                case .starting, .recording, .interrupted, .stopping:
                    RecorderView(coordinator: coordinator)
                        .transition(.opacity)
                case .idle, .blocked, .aborting:
                    HomeView(coordinator: coordinator, autoPresentID: $autoPresentID)
                        .transition(.opacity)
                }
            }
        }
        // Screen swaps fade instead of cutting; Reduce Motion turns the animation off.
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: screen)
        .sensoryFeedback(trigger: coordinator.state.phase) { old, new in
            Self.feedback(from: old, to: new)
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
