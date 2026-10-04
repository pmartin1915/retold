import AppIntents
import Foundation

// In-process hand-off from the intent to the coordinator. The intent runs in the app process
// (supportedModes = .foreground), so no App Group is needed: only the app's copy is ever reached.
// This file imports only AppIntents and Foundation because R6b compiles it into the widget
// extension too, as extension-safe code.

@MainActor final class CaptureLaunchInbox {
    static let shared = CaptureLaunchInbox()

    init() {}

    private(set) var pendingStarts = 0

    /// Set by the coordinator; called after every request() so a press that arrives after
    /// sceneDidBecomeActive (cold launch) is still drained.
    var onRequest: (@MainActor () -> Void)?

    func request() {
        pendingStarts += 1
        onRequest?()
    }

    /// True and resets to 0 if any start is pending.
    func take() -> Bool {
        guard pendingStarts > 0 else { return false }
        pendingStarts = 0
        return true
    }
}

struct StartCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a memory"
    static let description = IntentDescription("Opens Retold and starts recording.")
    static let supportedModes: IntentModes = .foreground(.immediate)   // iOS 26; NOT openAppWhenRun

    @MainActor func perform() async throws -> some IntentResult {
        CaptureLaunchInbox.shared.request()
        return .result()
    }
}
