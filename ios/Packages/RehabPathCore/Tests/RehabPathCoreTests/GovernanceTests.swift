import XCTest
@testable import RehabPathCore

final class GovernanceTests: XCTestCase {
    private let calendar = TestCalendar.auckland
    private let now = TestCalendar.date(2026, 10, 17, hour: 9)

    // MARK: Consent

    func testNotOnboardedWithoutCoreConsent() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        XCTAssertTrue(data.isOnboarded)

        data.consent = ConsentRecord(grantedAt: now, scopes: [.reminders])
        XCTAssertFalse(data.isOnboarded)
    }

    func testOutdatedConsentVersionRequiresReconsent() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        data.consent = ConsentRecord(version: "2020-01-legacy", grantedAt: now, scopes: [.coreProgramme])
        XCTAssertFalse(data.isOnboarded)
    }

    func testCoreConsentCannotBeToggledOff() {
        let consent = ConsentRecord(grantedAt: now, scopes: [.coreProgramme])
        XCTAssertTrue(consent.setting(.coreProgramme, granted: false).allows(.coreProgramme))
    }

    func testOptionalScopesCanBeGrantedAndWithdrawn() {
        let consent = ConsentRecord(grantedAt: now, scopes: [.coreProgramme])
        let granted = consent.setting(.aggregateResearch, granted: true)
        XCTAssertTrue(granted.allows(.aggregateResearch))
        XCTAssertFalse(granted.setting(.aggregateResearch, granted: false).allows(.aggregateResearch))
    }

    func testDataSharingScopesAreOffByDefault() {
        XCTAssertFalse(ConsentScope.defaultOptionalScopes.contains(.shareWithCareTeam))
        XCTAssertFalse(ConsentScope.defaultOptionalScopes.contains(.aggregateResearch))
    }

    func testCareTeamSharingIsOffByDefault() {
        XCTAssertTrue(CareTeamMember.samples.allSatisfy { !$0.isSharing })
    }

    // MARK: Retention

    func testRetentionRemovesOnlyExpiredCheckIns() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        let old = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: now))!
        data.checkIns.insert(DailyCheckIn(day: old, completedExerciseIDs: ["quad-sets"]), at: 0)
        let recentCount = data.checkIns.count - 1

        let retained = DataRetentionPolicy.standard.apply(to: data, asOf: now, calendar: calendar)
        XCTAssertEqual(retained.checkIns.count, recentCount)
        XCTAssertFalse(retained.checkIns.contains { $0.day == old })
    }

    // MARK: Export

    func testExportRoundTripsAllPatientData() throws {
        let data = AppData.sample(asOf: now, calendar: calendar)
        let json = try PersonalDataExport.makeJSON(from: data, exportedAt: now)
        let envelope = try PersonalDataExport.decode(json)
        XCTAssertEqual(envelope.format, PersonalDataExport.formatName)
        XCTAssertEqual(envelope.data, data)
    }

    // MARK: Validation

    func testPainScoresAreClamped() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        data.recordPain(42, on: now, calendar: calendar)
        XCTAssertEqual(data.checkIn(on: now, calendar: calendar)?.painScore, 10)
        data.recordPain(-1, on: now, calendar: calendar)
        XCTAssertEqual(data.checkIn(on: now, calendar: calendar)?.painScore, 0)
    }

    func testTogglingUnknownExerciseIsIgnored() {
        var data = AppData.sample(asOf: now, calendar: calendar)
        let before = data
        data.toggleExercise("unknown", on: now, calendar: calendar)
        XCTAssertEqual(data, before)
    }
}
