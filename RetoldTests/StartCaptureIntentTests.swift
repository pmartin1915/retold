import Foundation
import XCTest
@testable import Retold

/// The launch intent as a type (docs/R6-RECORDER-SPEC.md §5.3 and §6).
/// Only this file touches CaptureLaunchInbox.shared.
final class StartCaptureIntentTests: XCTestCase {
    @MainActor
    func testPerformRequestsAStart() async throws {
        // Reset any leftover pending start, and reset again on teardown.
        _ = CaptureLaunchInbox.shared.take()
        addTeardownBlock { @MainActor in _ = CaptureLaunchInbox.shared.take() }

        _ = try await StartCaptureIntent().perform()
        XCTAssertTrue(CaptureLaunchInbox.shared.take())
        // take() reset the counter: nothing is pending any more.
        XCTAssertFalse(CaptureLaunchInbox.shared.take())
    }

    @MainActor
    func testSupportedModesIsForegroundImmediate() {
        // IntentModes is an OptionSet-like type; contains avoids needing Equatable.
        XCTAssertTrue(StartCaptureIntent.supportedModes.contains(.foreground(.immediate)))
    }
}
