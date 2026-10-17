import Foundation
import Observation
import OSLog
import RehabPathCore

/// Single source of truth for the UI. Every mutation is persisted immediately.
@MainActor
@Observable
final class AppModel {
    private(set) var data: AppData
    /// Plain-language message for the patient when something goes wrong. Never contains health data.
    var errorMessage: String?

    @ObservationIgnored private let store: DataStore
    @ObservationIgnored private let reminders: ReminderScheduling
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let clock: () -> Date
    // Log events only — never patient data (DATA_GOVERNANCE.md §7.3).
    @ObservationIgnored private let log = Logger(subsystem: "nz.co.rehabpath.app", category: "AppModel")

    init(
        store: DataStore,
        reminders: ReminderScheduling = NoReminders(),
        calendar: Calendar = .current,
        clock: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.reminders = reminders
        self.calendar = calendar
        self.clock = clock
        do {
            data = DataRetentionPolicy.standard.apply(to: try store.load(), asOf: clock(), calendar: calendar)
        } catch {
            data = .empty
            errorMessage = "We couldn't open your saved progress. Your data hasn't been changed."
            log.error("Failed to load data store")
        }
    }

    // MARK: Derived state

    var now: Date { clock() }
    var engine: AdherenceEngine { AdherenceEngine(calendar: calendar) }
    var summary: AdherenceSummary { engine.summary(for: data, asOf: now) }
    var nudge: Nudge { engine.nudge(for: data, asOf: now) }
    var today: DailyCheckIn? { data.checkIn(on: now, calendar: calendar) }
    var exercises: [Exercise] { data.programme.exercises }
    var completedTodayCount: Int { engine.completion(on: now, in: data).completed }

    func isCompletedToday(_ exercise: Exercise) -> Bool {
        today?.completedExerciseIDs.contains(exercise.id) ?? false
    }

    func allows(_ scope: ConsentScope) -> Bool {
        data.consent?.allows(scope) ?? false
    }

    // MARK: Onboarding

    func completeOnboarding(name: String, goal: String, baselinePain: Int, optionalScopes: Set<ConsentScope>) {
        let startedAt = now
        data.profile = PatientProfile(
            preferredName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            recoveryGoal: goal.trimmingCharacters(in: .whitespacesAndNewlines),
            programmeStartDate: calendar.startOfDay(for: startedAt),
            baselinePain: baselinePain
        )
        data.consent = ConsentRecord(grantedAt: startedAt, scopes: optionalScopes.union([.coreProgramme]))
        persist()
        if optionalScopes.contains(.reminders) {
            enableReminders()
        }
    }

    // MARK: Daily check-in

    func toggle(_ exercise: Exercise) {
        data.toggleExercise(exercise.id, on: now, calendar: calendar)
        persist()
    }

    func recordPain(_ score: Int) {
        data.recordPain(score, on: now, calendar: calendar)
        persist()
    }

    // MARK: Care team

    func setSharing(_ memberID: CareTeamMember.ID, enabled: Bool) {
        guard let index = data.careTeam.firstIndex(where: { $0.id == memberID }) else { return }
        data.careTeam[index].isSharing = enabled && allows(.shareWithCareTeam)
        persist()
    }

    // MARK: Consent and patient rights

    func setConsent(_ scope: ConsentScope, granted: Bool) {
        guard let consent = data.consent else { return }
        data.consent = consent.setting(scope, granted: granted)
        if scope == .shareWithCareTeam, !granted {
            // Withdrawing consent stops all sharing immediately.
            for index in data.careTeam.indices {
                data.careTeam[index].isSharing = false
            }
        }
        persist()
        if scope == .reminders {
            if granted {
                enableReminders()
            } else {
                reminders.disable()
            }
        }
    }

    /// Called while rendering the Privacy tab, so it must not mutate observed state.
    func exportJSON() -> Data? {
        do {
            return try PersonalDataExport.makeJSON(from: data, exportedAt: now)
        } catch {
            log.error("Export failed")
            return nil
        }
    }

    /// Erases everything on this device and returns the app to onboarding.
    func deleteAllData() {
        reminders.disable()
        do {
            try store.deleteAll()
            data = .empty
        } catch {
            log.error("Delete failed")
            errorMessage = "We couldn't delete your data. Please try again, or delete the app to remove it."
        }
    }

    // MARK: Private

    private func enableReminders() {
        Task {
            let granted = await reminders.enableDailyReminder(hour: AppConfig.reminderHour)
            if !granted, let consent = data.consent {
                // Respect the system-level answer: keep in-app state truthful.
                data.consent = consent.setting(.reminders, granted: false)
                persist()
            }
        }
    }

    private func persist() {
        do {
            try store.save(data)
        } catch {
            log.error("Save failed")
            errorMessage = "Your latest change couldn't be saved. Please try again."
        }
    }
}
