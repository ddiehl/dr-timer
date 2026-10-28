import XCTest

/// Drives the app to each screen worth showing on the App Store and attaches a
/// full-screen capture of it. The flights and the in-progress run are seeded
/// into the app container beforehand by scripts/screenshots.sh, so these tests
/// only navigate — they never create data through the UI.
///
/// A run in progress hides the tab bar (RunView sets `.toolbar(.hidden,
/// for: .tabBar)`), so the planning screens are captured in the scenario that
/// seeds no run, and the countdown screens in the scenarios that do.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The notification prompt fires the first time the Fly tab appears and
    /// would sit on top of every capture, so it is answered before shooting.
    private func dismissNotificationPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        dismissNotificationPromptIfPresent()
        return app
    }

    /// Seeded with a run counting down, so the app restores straight into it.
    func testCounting() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["LEG 3 OF 5"].waitForExistence(timeout: 10),
                      "expected the seeded run to restore into leg 3 of 5")
        shoot("01-counting")
    }

    /// Seeded with a leg that ends a few seconds after launch, so the time-up
    /// screen is reached the way a pilot reaches it rather than by faking state.
    func testTimeUp() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["LOOK FOR"].waitForExistence(timeout: 40),
                      "expected the seeded leg to reach time-up")
        shoot("02-time-up")
    }

    /// No run seeded: the tab bar is available, so this scenario covers the
    /// picker and every planning screen.
    func testPickerPlanAndAbout() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["KPAO → KSAC Dual X-C"].waitForExistence(timeout: 10),
                      "expected the seeded flights in the picker")
        shoot("03-picker")

        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.navigationBars["Flights"].waitForExistence(timeout: 5))
        shoot("04-flights")

        app.staticTexts["KSQL → KMRY Coastal"].tap()
        XCTAssertTrue(app.staticTexts["Crystal Springs Res."].waitForExistence(timeout: 5))
        shoot("05-editor")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Flights"].waitForExistence(timeout: 5))

        app.buttons["About"].tap()
        XCTAssertTrue(app.staticTexts["Pilot Timer"].waitForExistence(timeout: 5))
        shoot("06-about")
    }
}
