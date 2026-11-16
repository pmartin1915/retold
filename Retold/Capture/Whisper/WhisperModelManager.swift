import Foundation
import Network
import Observation

// The offered model (docs/WHISPER-PASS-SPEC.md section 5): download on Wi-Fi only, prepared (first
// load, which compiles it) before it counts as ready, and deleted on request. The importer's
// readiness check is the store's marker, which this writes only after that first load.

@MainActor @Observable
final class WhisperModelManager {
    static let shared = WhisperModelManager()

    enum State: Equatable {
        case absent
        case waitingForWiFi
        case downloading(percent: Int)
        case preparing
        case ready(megabytes: Int)
        case failed(String)
    }

    private(set) var state: State

    @ObservationIgnored private let spec = WhisperModelSpec.turbo
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var onWiFi = false
    @ObservationIgnored private var task: Task<Void, Never>?
    /// The user asked for the model; survives relaunch so a wait for Wi-Fi resumes.
    private var wanted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.wantedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.wantedKey) }
    }
    private static let wantedKey = "retold.whisper.wanted"

    private init() {
        if WhisperModelStore.downloadedFolder(for: spec) != nil {
            state = .ready(megabytes: WhisperModelStore.downloadedMB)
        } else {
            state = UserDefaults.standard.bool(forKey: Self.wantedKey) ? .waitingForWiFi : .absent
        }
        // The shared instance lives for the process, so the handler holds it strongly.
        // Explicitly @Sendable, so it is not main-actor isolated: the monitor calls it on its own queue.
        let handler: @Sendable (NWPath) -> Void = { [self] path in
            let wifi = path.status == .satisfied && path.usesInterfaceType(.wifi)
                && !path.isExpensive && !path.isConstrained
            Task { @MainActor in self.pathChanged(wifi: wifi) }
        }
        monitor.pathUpdateHandler = handler
        monitor.start(queue: DispatchQueue(label: "retold.whisper.path"))
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// The prompt's Download and the Settings row's Download/Retry.
    func requestDownload() {
        wanted = true
        if case .failed = state { state = .absent }
        startIfPossible()
    }

    /// Cancels any download, waits for a running pass to end, then deletes every Whisper model.
    func delete(waitingFor coordinator: CaptureCoordinator?) async {
        wanted = false
        task?.cancel()
        await task?.value
        await coordinator?.awaitFilePass()
        WhisperModelStore.deleteAll()
        state = .absent
    }

    private func pathChanged(wifi: Bool) {
        onWiFi = wifi
        if wifi {
            startIfPossible()
        } else if task != nil, case .downloading = state {
            task?.cancel()       // Wi-Fi only: never finish a download on cellular
        }
    }

    private func startIfPossible() {
        guard wanted, task == nil else { return }
        if WhisperModelStore.downloadedFolder(for: spec) != nil {
            state = .ready(megabytes: WhisperModelStore.downloadedMB)
            return
        }
        guard onWiFi else {
            state = .waitingForWiFi
            return
        }
        state = .downloading(percent: 0)
        task = Task {
            await run()
            task = nil
            resumeIfWanted()
        }
    }

    /// After a cancelled run (Wi-Fi lost), wait for Wi-Fi again.
    private func resumeIfWanted() {
        guard wanted, !isReady else { return }
        if case .failed = state { return }
        startIfPossible()
    }

    private func run() async {
        let spec = self.spec
        do {
            let folder = try await WhisperModelStore.download(spec) { tenth in
                Task { @MainActor in
                    guard case .downloading = self.state else { return }
                    self.state = .downloading(percent: tenth * 10)
                }
            }
            try Task.checkCancellation()
            state = .preparing
            // Never load beside a recording (Sol review of PR #40): wait for the capture to end.
            while WhisperModelGate.captureActive {
                try await Task.sleep(for: .seconds(1))
            }
            // The first load compiles the model (minutes); doing it here keeps it off the after-Stop pass.
            let runner = WhisperRunner(spec: spec)
            do {
                _ = try await runner.load(folder: folder)
                await runner.unload()
            } catch {
                await runner.unload()
                throw error
            }
            try Task.checkCancellation()
            WhisperModelStore.recordDownload(of: spec, at: folder)
            wanted = false
            state = .ready(megabytes: WhisperModelStore.downloadedMB)
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = wanted ? .waitingForWiFi : .absent
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
