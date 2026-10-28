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

    private enum EdgeZone { case top, bottom }

    /// Audits a screen twice — at the top and scrolled to the bottom. iOS 26 softens content near
    /// the nav and tab bars, and the audit then measures blurred pixels instead of the text. So the
    /// top pass skips contrast findings on text in the bottom edge zone, and the bottom pass skips
    /// those in the top edge zone; every element is checked at rest in at least one pass.
    /// Reports every issue (not just the first) so one CI run shows the full list.
    private func audit(screen: String) throws {
        // setUp stops tests at the first failure; keep going so one run lists every audit issue.
        let stopAtFirstFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = stopAtFirstFailure }
        settle()
        try runAudit(screen: "\(screen) top", skipping: .bottom)
        for _ in 0..<3 { app.swipeUp() }
        settle()
        try runAudit(screen: "\(screen) bottom", skipping: .top)
        for _ in 0..<3 { app.swipeDown() }
        settle()
    }

    /// Lets tab-switch and scroll-deceleration animations finish, so the audit measures a still
    /// screen rather than frames captured mid-motion.
    private func settle(seconds: TimeInterval = 1.5) {
        let pause = XCTestExpectation(description: "settle")
        pause.isInverted = true
        _ = XCTWaiter.wait(for: [pause], timeout: seconds)
    }

    private func runAudit(screen: String, skipping zone: EdgeZone) throws {
        let window = app.windows.firstMatch.frame
        let edgeBlur: CGFloat = 60
        let skipRegion: CGRect = switch zone {
        case .top:
            CGRect(x: 0, y: 0, width: window.width, height: app.navigationBars.firstMatch.frame.maxY + edgeBlur)
        case .bottom:
            CGRect(x: 0, y: app.tabBars.firstMatch.frame.minY - edgeBlur, width: window.width,
                   height: window.height - app.tabBars.firstMatch.frame.minY + edgeBlur)
        }
        let barOwnLabels = Set(
            (app.tabBars.firstMatch.descendants(matching: .any).allElementsBoundByIndex
                + app.navigationBars.firstMatch.descendants(matching: .any).allElementsBoundByIndex).map(\.label)
        )
        try app.performAccessibilityAudit { issue in
            let element = issue.element
            if issue.auditType == .contrast,
               let element,
               element.elementType == .staticText,
               !barOwnLabels.contains(element.label),
               skipRegion.intersects(element.frame) {
                return true  // in the bar-blur zone for this pass; audited at rest in the other pass
            }
            let detail = element.map { "\($0.elementType.rawValue) \"\($0.label)\" frame=\($0.frame)" } ?? "unknown element"
            XCTFail("[\(screen)] \(issue.compactDescription) | \(issue.detailedDescription) | \(detail)")
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
