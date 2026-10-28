import XCTest

/// Captures every screen for design review; asserts nothing about behaviour.
/// CI runs it on its own (see .github/workflows/ios.yml) and publishes the PNGs as the
/// "screenshots" artifact. Data is always the synthetic sample set (-seed-onboarded).
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    func testOnboarding() {
        launch(set: "onboarding", seeded: false)
        capture("01-welcome")
        let name = app.textFields["onboarding.name"]
        if name.waitForExistence(timeout: 5) {
            name.tap()
            name.typeText("Aroha")
            let goal = app.textFields["onboarding.goal"]
            goal.tap()
            goal.typeText("Walking the dog")
        }
        capture("02-welcome-filled-in")
        app.buttons["onboarding.continue"].tap()
        capture("03-pain-baseline")
        app.buttons["onboarding.continue"].tap()
        capture("04-consent")
        switchOn(app.switches["consent.core"])
        capture("05-consent-agreed")
        app.buttons["onboarding.agree"].tap()
        _ = app.staticTexts["today.progress"].waitForExistence(timeout: 5)
        capture("06-first-day")
    }

    func testMainScreensLight() {
        captureMainScreens(set: "light")
    }

    func testMainScreensDark() {
        captureMainScreens(set: "dark", extraArguments: ["-AppleInterfaceStyle", "Dark"])
    }

    func testMainScreensLargeText() {
        captureMainScreens(
            set: "large-text",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        )
    }

    // MARK: Helpers

    private func captureMainScreens(set: String, extraArguments: [String] = []) {
        launch(set: set, seeded: true, extraArguments: extraArguments)
        _ = app.staticTexts["today.progress"].waitForExistence(timeout: 5)
        capture("01-today")
        scrollDown()
        capture("02-today-pain-check-in")
        app.tabBars.buttons["Progress"].tap()
        capture("03-progress")
        app.tabBars.buttons["Care team"].tap()
        capture("04-care-team")
        app.tabBars.buttons["Privacy"].tap()
        capture("05-privacy")
        scrollDown()
        capture("06-privacy-rights")
        let delete = app.buttons["privacy.delete"]
        if delete.waitForExistence(timeout: 3), delete.isHittable {
            delete.tap()
            capture("07-delete-confirmation")
        }
    }

    private func launch(set: String, seeded: Bool, extraArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seeded ? ["-seed-onboarded"] : []) + extraArguments
        app.launch()
        currentSet = set
    }

    private var currentSet = ""

    private func scrollDown() {
        for _ in 0..<3 { app.swipeUp() }
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)  // let animations finish before the shot
        let shot = XCUIScreen.main.screenshot()
        let fileName = "\(currentSet)-\(name)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(fileName).png"))
    }
}
