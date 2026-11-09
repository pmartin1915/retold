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

    /// A recording that cannot play says so (comeup run 2 P4). The demo's audio files are four
    /// placeholder bytes, so AVAudioPlayer cannot decode them: the failure path, every time.
    /// Also shows the story page's new order (recordings before questions).
    func testPlaybackFailureIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-RetoldDemo"]
        app.launch()

        let story = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Summers at the lake house")).firstMatch
        _ = story.waitForExistence(timeout: 10)
        for _ in 0..<6 where !(story.exists && story.isHittable) {
            app.swipeUp()
        }
        guard story.exists, story.isHittable else {
            XCTFail("Demo story row not reachable")
            return
        }
        story.tap()
        settle(1.0)
        attach(app, named: "check-story-order")

        let play = app.buttons["Play"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10), "Story page has no Play button")
        play.tap()
        let failure = app.staticTexts["This recording could not play. Try again in a moment."].firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 5), "Playback failure is not shown")
        attach(app, named: "check-playback-failed")
    }

    /// V5 (Perry's pick): the story page folds its questions into one "Questions (n)" row under the
    /// recordings; opening it shows the offers.
    func testStoryQuestionsFoldIntoOneRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-RetoldDemo"]
        app.launch()
        guard openStory(in: app) else { return }

        let folded = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Questions (")).firstMatch
        XCTAssertTrue(folded.waitForExistence(timeout: 10), "No folded Questions row on the story page")
        XCTAssertFalse(app.buttons["Answer now"].exists, "Questions are not folded")
        folded.tap()
        // The list is lazy: opened offer rows below the fold exist only once scrolled into view.
        let answer = app.buttons["Answer now"].firstMatch
        for _ in 0..<4 {
            if answer.waitForExistence(timeout: 2) { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(answer.waitForExistence(timeout: 2), "Questions did not open")
        settle(1.0)
        attach(app, named: "check-story-questions-open")
    }

    /// V2 (Perry's pick): File it shows a brief "Filed: <title>" pill on Home.
    func testFilingShowsFiledPill() {
        let app = XCUIApplication()
        app.launchArguments = ["-RetoldDemo"]
        app.launch()

        let unfiled = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Grandpa Joe taught me")).firstMatch
        XCTAssertTrue(unfiled.waitForExistence(timeout: 10), "Unfiled demo row missing")
        unfiled.tap()
        let useTitle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Use this")).firstMatch
        XCTAssertTrue(useTitle.waitForExistence(timeout: 15), "Confirm sheet has no suggestion")
        useTitle.tap()
        let fileButton = app.buttons["File it"].firstMatch
        XCTAssertTrue(fileButton.waitForExistence(timeout: 5), "No File it button")
        fileButton.tap()
        let pill = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Filed: ")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "No Filed pill after File it")
        attach(app, named: "check-filed-pill")
    }

    /// Opens the demo story "Summers at the lake house" from Home.
    private func openStory(in app: XCUIApplication) -> Bool {
        let story = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Summers at the lake house")).firstMatch
        _ = story.waitForExistence(timeout: 10)
        for _ in 0..<6 where !(story.exists && story.isHittable) {
            app.swipeUp()
        }
        guard story.exists, story.isHittable else {
            XCTFail("Demo story row not reachable")
            return false
        }
        story.tap()
        settle(1.0)
        return true
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
