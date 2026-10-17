import SwiftUI
import RehabPathCore

@main
struct RehabPathApp: App {
    @State private var model = AppModel.makeForLaunch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

extension AppModel {
    /// UI tests launch with `-ui-testing` (and optionally `-seed-onboarded`) so they never touch
    /// the real data file and never trigger a notification permission prompt.
    static func makeForLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        if arguments.contains(LaunchArgument.uiTesting) {
            let seed = arguments.contains(LaunchArgument.seedOnboarded)
                ? AppData.sample(asOf: .now, calendar: .current)
                : nil
            return AppModel(store: InMemoryDataStore(seed), reminders: NoReminders())
        }
        return AppModel(store: FileDataStore(directory: URL.applicationSupportDirectory), reminders: NotificationReminders())
    }
}

enum LaunchArgument {
    static let uiTesting = "-ui-testing"
    static let seedOnboarded = "-seed-onboarded"
}
