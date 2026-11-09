import XCTest

/// Flow checks that are not App Store screenshots (comeup run 2). Each attaches `check-*`
/// screenshots, which screenshots.yml uploads as the ui-checks artifact for Claude to read.
/// Labels are AppCopy's strings, copied (the UI-test bundle cannot see app code).
@MainActor
final class FlowTests: XCTestCase {
    /// Startup failure shows a designed error state whose Try again recovers without a relaunch.
    /// `-RetoldFailFirstStart` (DEBUG only) makes the first storage open throw.
    func testStartupFailureTryAgainRecovers() {
        let app = XCUIApplication()
        app.launchArguments = ["-RetoldDemo", "-RetoldFailFirstStart"]
        app.launch()

        let tryAgain = app.buttons["Try again"].firstMatch
        XCTAssertTrue(tryAgain.waitForExistence(timeout: 10), "Startup failure has no Try again button")
        XCTAssertTrue(app.staticTexts["Retold could not start"].exists, "Startup failure title missing")
        attach(app, named: "check-startup-failed")

        tryAgain.tap()
        let recordButton = app.buttons["Record a memory"].firstMatch
        XCTAssertTrue(recordButton.waitForExistence(timeout: 10), "Try again did not reach Home")
        attach(app, named: "check-startup-recovered")
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
