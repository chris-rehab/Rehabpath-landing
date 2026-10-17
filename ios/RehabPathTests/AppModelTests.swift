import XCTest
import RehabPathCore
@testable import RehabPath

@MainActor
final class AppModelTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return calendar
    }()
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9))!

    private func makeModel(_ store: InMemoryDataStore = InMemoryDataStore(), reminders: ReminderScheduling = NoReminders()) -> AppModel {
        AppModel(store: store, reminders: reminders, calendar: calendar, clock: { [now] in now })
    }

    func testOnboardingPersistsProfileAndConsent() throws {
        let store = InMemoryDataStore()
        let model = makeModel(store)
        XCTAssertFalse(model.data.isOnboarded)

        model.completeOnboarding(name: "  Aroha ", goal: "netball", baselinePain: 6, optionalScopes: [])

        XCTAssertTrue(model.data.isOnboarded)
        XCTAssertEqual(model.data.profile?.preferredName, "Aroha")
        XCTAssertEqual(model.data.consent?.scopes, [.coreProgramme])
        XCTAssertEqual(try store.load(), model.data)
    }

    func testToggleExercisePersists() throws {
        let store = InMemoryDataStore(AppData.sample(asOf: now, calendar: calendar))
        let model = makeModel(store)
        let exercise = model.exercises[4]
        XCTAssertFalse(model.isCompletedToday(exercise))

        model.toggle(exercise)

        XCTAssertTrue(model.isCompletedToday(exercise))
        XCTAssertEqual(try store.load().checkIn(on: now, calendar: calendar)?.completedExerciseIDs.contains(exercise.id), true)
    }

    func testSharingRequiresConsent() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        data.consent?.scopes = [.coreProgramme]
        data.careTeam = CareTeamMember.samples
        let model = makeModel(InMemoryDataStore(data))

        model.setSharing(data.careTeam[1].id, enabled: true)

        XCTAssertFalse(model.data.careTeam[1].isSharing)
    }

    func testWithdrawingSharingConsentStopsAllSharing() {
        let model = makeModel(InMemoryDataStore(AppData.sample(asOf: now, calendar: calendar)))
        XCTAssertTrue(model.data.careTeam.contains(where: \.isSharing))

        model.setConsent(.shareWithCareTeam, granted: false)

        XCTAssertFalse(model.data.careTeam.contains(where: \.isSharing))
    }

    func testDeleteAllDataReturnsToOnboarding() {
        let store = InMemoryDataStore(AppData.sample(asOf: now, calendar: calendar))
        let reminders = SpyReminders()
        let model = makeModel(store, reminders: reminders)

        model.deleteAllData()

        XCTAssertFalse(model.data.isOnboarded)
        XCTAssertFalse(store.hasData)
        XCTAssertTrue(reminders.disabled)
    }

    func testExportContainsPatientData() throws {
        let model = makeModel(InMemoryDataStore(AppData.sample(asOf: now, calendar: calendar)))
        let json = try XCTUnwrap(model.exportJSON())
        XCTAssertEqual(try PersonalDataExport.decode(json).data, model.data)
    }

    func testDeclinedNotificationPermissionWithdrawsReminderConsent() async {
        let reminders = SpyReminders(grant: false)
        let model = makeModel(reminders: reminders)

        model.completeOnboarding(name: "Aroha", goal: "netball", baselinePain: 5, optionalScopes: [.reminders])
        var attempts = 0
        while model.allows(.reminders), attempts < 100 {
            await Task.yield()
            attempts += 1
        }

        XCTAssertTrue(reminders.requested)
        XCTAssertFalse(model.allows(.reminders))
    }

    func testRetentionPolicyAppliedOnLaunch() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        let old = calendar.date(byAdding: .day, value: -500, to: now)!
        data.checkIns.insert(DailyCheckIn(day: calendar.startOfDay(for: old), completedExerciseIDs: ["quad-sets"]), at: 0)

        let model = makeModel(InMemoryDataStore(data))

        XCTAssertEqual(model.data.checkIns.count, data.checkIns.count - 1)
    }
}

final class SpyReminders: ReminderScheduling, @unchecked Sendable {
    private let grant: Bool
    private(set) var requested = false
    private(set) var disabled = false

    init(grant: Bool = true) {
        self.grant = grant
    }

    func enableDailyReminder(hour: Int) async -> Bool {
        requested = true
        return grant
    }

    func disable() {
        disabled = true
    }
}
