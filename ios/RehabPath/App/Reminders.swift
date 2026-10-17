import Foundation
import UserNotifications

protocol ReminderScheduling {
    /// Requests permission if needed and schedules one daily reminder. Returns false if the
    /// patient declined in the system prompt.
    func enableDailyReminder(hour: Int) async -> Bool
    func disable()
}

/// Local notifications only — no push, no server. The notification text is deliberately
/// generic so no health information appears on the lock screen (DATA_GOVERNANCE.md §7.4).
struct NotificationReminders: ReminderScheduling {
    private static let identifier = "daily-programme-reminder"

    func enableDailyReminder(hour: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "RehabPath"
        content.body = "A few minutes for today's exercises?"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour), repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

struct NoReminders: ReminderScheduling {
    func enableDailyReminder(hour: Int) async -> Bool { true }
    func disable() {}
}
