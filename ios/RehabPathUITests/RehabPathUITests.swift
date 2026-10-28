import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingRequiresConsentThenShowsToday() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue needs a name and goal")

        let name = app.textFields["onboarding.name"]
        name.tap()
        name.typeText("Aroha")
        let goal = app.textFields["onboarding.goal"]
        goal.tap()
        goal.typeText("Netball")
        continueButton.tap()

        // Pain baseline step
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 2))
        continueButton.tap()

        // Consent step: cannot start without core consent
        let agree = app.buttons["onboarding.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 2))
        XCTAssertFalse(agree.isEnabled)
        XCTAssertEqual(app.switches["consent.shareWithCareTeam"].value as? String, "0", "Sharing must default to off")
        XCTAssertEqual(app.switches["consent.aggregateResearch"].value as? String, "0", "Research must default to off")

        switchOn(app.switches["consent.core"])
        XCTAssertTrue(agree.isEnabled)
        agree.tap()

        XCTAssertTrue(app.navigationBars["Kia ora, Aroha"].waitForExistence(timeout: 3))
    }
}

final class MainAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed-onboarded"]
        app.launch()
    }

    func testCompletingAnExerciseUpdatesProgress() {
        let progress = app.staticTexts["today.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        XCTAssertEqual(progress.label, "2 of 5 done")

        app.buttons["exercise.mini-squats"].tap()

        XCTAssertEqual(progress.label, "3 of 5 done")
        XCTAssertEqual(app.buttons["exercise.mini-squats"].value as? String, "Done")
    }

    func testDeleteAllDataReturnsToOnboarding() {
        app.tabBars.buttons["Privacy"].tap()
        let delete = app.buttons["privacy.delete"]
        scrollTo(delete)
        delete.tap()
        app.buttons["Delete everything"].firstMatch.tap()

        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 3))
    }

    func testPrivacyTabOffersDataExport() {
        app.tabBars.buttons["Privacy"].tap()
        let export = app.buttons["privacy.export"]
        scrollTo(export)
        XCTAssertTrue(export.exists)
    }

    // MARK: Apple accessibility audit (Xcode 15+): contrast, Dynamic Type, hit regions, labels.

    func testAccessibilityAuditToday() throws {
        try audit(screen: "Today")
    }

    func testAccessibilityAuditAllTabs() throws {
        for tab in ["Progress", "Care team", "Privacy"] {
            app.tabBars.buttons[tab].tap()
            try audit(screen: tab)
        }
    }

    /// Reports every issue on the screen (not just the first) so one CI run shows the full list.
    private func audit(screen: String) throws {
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) \"\($0.label)\" frame=\($0.frame)" } ?? "unknown element"
            XCTFail("[\(screen)] \(issue.compactDescription) | \(issue.detailedDescription) | \(element)")
            return true
        }
    }

    private func scrollTo(_ element: XCUIElement) {
        var swipes = 0
        while !element.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
    }
}

/// SwiftUI toggles with long labels: tapping the element centre can hit the label, so tap the switch side.
func switchOn(_ toggle: XCUIElement) {
    if toggle.value as? String != "1" {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
