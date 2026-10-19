import XCTest

/// App Store screenshots. Launches the app in demo mode (`-RetoldDemo`): an in-memory, fictional
/// library with mock capture already granted the microphone, so no system permission alert can
/// appear and no interruption monitor is needed. Each screenshot is attached with a fixed name;
/// CI renames the exported attachments by these names. The UI-test bundle cannot see app code, so
/// the labels below are AppCopy's and DemoMode's strings, copied.
@MainActor
final class ScreenshotTests: XCTestCase {

    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-RetoldDemo"]
        app.launch()

        // 01-home: the library, with the seeded stories under their periods.
        let recordButton = app.buttons["Record a memory"].firstMatch
        guard waitForScreen(recordButton, named: "01-home (home)") else { return }
        settle()
        attachScreenshot(of: app, named: "01-home")

        // 02-recorder: Record a memory -> the recorder, with the demo engine's live text.
        recordButton.tap()
        let stopButton = app.buttons["Stop"].firstMatch
        guard waitForScreen(stopButton, named: "02-recorder (recorder)") else { return }
        let liveText = labelled("smell of bread", in: app)
        guard waitForScreen(liveText, named: "02-recorder (live text)") else { return }
        attachScreenshot(of: app, named: "02-recorder")

        // Stop returns to home (the demo capture has no audio, so nothing is auto-presented).
        stopButton.tap()
        guard waitForScreen(recordButton, named: "home after Stop") else { return }

        // 04-story: one filed story's page, its facts, player and verbatim transcript.
        let story = labelled("Summers at the lake house", in: app)
        guard scrollTo(story, in: app, named: "04-story (home row)") else { return }
        story.tap()
        let storyPage = app.navigationBars["Summers at the lake house"].firstMatch
        guard waitForScreen(storyPage, named: "04-story (story page)") else { return }
        settle()
        attachScreenshot(of: app, named: "04-story")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 05-browse: People -> Grandpa Joe, his questions and stories.
        let peopleLink = app.buttons["People"].firstMatch
        guard scrollTo(peopleLink, in: app, named: "05-browse (People link)") else { return }
        peopleLink.tap()
        let grandpa = app.buttons["Grandpa Joe"].firstMatch
        guard waitForScreen(grandpa, named: "05-browse (People list)") else { return }
        grandpa.tap()
        let personPage = app.navigationBars["Grandpa Joe"].firstMatch
        guard waitForScreen(personPage, named: "05-browse (Grandpa Joe)") else { return }
        settle()
        attachScreenshot(of: app, named: "05-browse")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 03-confirm last: the confirm sheet has no Cancel, so nothing has to dismiss it.
        let unfiled = labelled("Grandpa Joe taught me", in: app)
        guard scrollTo(unfiled, in: app, named: "03-confirm (unfiled row)") else { return }
        unfiled.tap()
        let suggestion = app.buttons["Use this"].firstMatch
        guard waitForScreen(suggestion, named: "03-confirm (confirm with suggestions)") else { return }
        settle()
        attachScreenshot(of: app, named: "03-confirm")
    }

    /// The first element whose label contains `text` (rows merge their texts into one label).
    private func labelled(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// Waits for `element`, swiping up (lists are lazy) or back down a few times if needed.
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, named screen: String) -> Bool {
        if element.waitForExistence(timeout: 5), element.isHittable { return true }
        for _ in 0..<4 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            app.swipeDown()
        }
        guard element.exists, element.isHittable else {
            XCTFail("Screen \(screen) did not appear")
            return false
        }
        return true
    }

    /// Waits up to 10 s for the screen's anchor element and fails naming the screen.
    private func waitForScreen(_ element: XCUIElement, named screen: String) -> Bool {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Screen \(screen) did not appear within 10 seconds")
            return false
        }
        return true
    }

    /// Lets a push or sheet animation finish before the screenshot.
    private func settle() {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.0)
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
