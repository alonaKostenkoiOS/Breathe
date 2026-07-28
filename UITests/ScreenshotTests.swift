import XCTest

/// Captures App Store / README screenshots by driving the app through its
/// main screens with a seeded, in-memory environment. Screenshots are
/// attached to the test result and exported with `xcresulttool`.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func makeApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeed"] + extraArguments
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// English walkthrough of every screen.
    func testCaptureScreens() {
        let app = makeApp(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Your smoke-free journey"].waitForExistence(timeout: 10))
        capture("01-dashboard")

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        capture("02-recovery")

        app.tabBars.buttons["Cravings"].tap()
        XCTAssertTrue(app.navigationBars["Cravings"].waitForExistence(timeout: 5))
        capture("03-cravings")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("04-settings")

        app.tabBars.buttons["Cravings"].tap()
        app.navigationBars["Cravings"].buttons["Log a craving"].tap()
        XCTAssertTrue(app.navigationBars["Log a craving"].waitForExistence(timeout: 5))
        capture("05-log-craving")

        app.buttons["Close"].tap()
        app.tabBars.buttons["Home"].tap()
        app.buttons["I’m having a craving"].tap()
        XCTAssertTrue(app.staticTexts["Craving Rescue"].waitForExistence(timeout: 5))
        capture("06-craving-rescue")
    }

    /// Same dashboard rendered in Ukrainian, to show off localisation.
    func testCaptureUkrainianDashboard() {
        let app = makeApp(extraArguments: ["-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"])
        app.launch()

        // Dismiss any incidental system alert that can steal focus.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Cancel"].waitForExistence(timeout: 2) {
            springboard.buttons["Cancel"].tap()
        }

        XCTAssertTrue(app.navigationBars["Головна"].waitForExistence(timeout: 10))
        capture("07-ukrainian")
    }
}
