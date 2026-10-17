import Foundation

enum AppConfig {
    // App Store blocker: these pages must be live before submission (APP_STORE_READINESS.md).
    static let privacyPolicyURL = URL(string: "https://rehabpath.co.nz/privacy.html")!
    static let supportURL = URL(string: "https://rehabpath.co.nz/support.html")!
    static let privacyEmail = "privacy@rehabpath.co.nz"

    /// Daily reminder time (local), 6 pm.
    static let reminderHour = 18
}
