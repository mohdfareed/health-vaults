import XCTest

// MARK: - UI Tests
// ============================================================================
// UI tests run against the full app on a simulator.
// Use XCUIApplication to interact with the app UI and assert on its state.
// Add test methods here as UI coverage grows.

@MainActor
final class LaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Inject arguments/environment to make tests deterministic and enable test-only code paths.
        app.launchArguments += [
            "-UITests",              // Generic flag to detect UI test mode in the app
            "-ui_disableAnimations", // App can read this to disable animations
            "-ui_skipOnboarding",    // App can skip onboarding for tests
        ]
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launch()
    }

    override func tearDown() async throws {
        if testRun?.hasSucceeded == false {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure Screenshot"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    func testLaunch() async throws {
        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window did not appear in time.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

