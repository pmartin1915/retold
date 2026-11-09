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

    /// Largest accessibility text size (house style rule 18, "check at AX5"): Home and the confirm
    /// sheet must still show their primary content. Screenshots go to the ui-checks artifact.
    func testAccessibilityTextSizeHomeAndConfirm() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-RetoldDemo",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let recordButton = app.buttons["Record a memory"].firstMatch
        XCTAssertTrue(recordButton.waitForExistence(timeout: 10), "Home did not appear at AX5")
        settle(1.0)
        attach(app, named: "check-ax5-home")

        let unfiled = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Grandpa Joe taught me")).firstMatch
        // At AX5 the list is far taller than the screen and lazy: swipe until the row is hittable.
        _ = unfiled.waitForExistence(timeout: 5)
        for _ in 0..<6 where !(unfiled.exists && unfiled.isHittable) {
            app.swipeUp()
        }
        guard unfiled.exists, unfiled.isHittable else {
            XCTFail("Unfiled demo row not reachable at AX5")
            return
        }
        unfiled.tap()
        let fileButton = app.buttons["File it"].firstMatch
        XCTAssertTrue(fileButton.waitForExistence(timeout: 15), "Confirm sheet did not appear at AX5")
        settle(2.0)
        attach(app, named: "check-ax5-confirm")
    }

    private func settle(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
