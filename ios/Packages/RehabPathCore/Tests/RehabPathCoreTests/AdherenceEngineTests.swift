import XCTest
@testable import RehabPathCore

final class AdherenceEngineTests: XCTestCase {
    private let calendar = TestCalendar.auckland
    private lazy var engine = AdherenceEngine(calendar: calendar)
    private lazy var now = TestCalendar.date(2026, 10, 17, hour: 18)
    private let allIDs = Programme.sampleKnee.exercises.map(\.id)

    func testProgrammeDayStartsAtOne() {
        let data = makeData(startDaysAgo: 0)
        XCTAssertEqual(engine.programmeDay(for: data, asOf: now), 1)
        XCTAssertEqual(engine.programmeDay(for: makeData(startDaysAgo: 9), asOf: now), 10)
    }

    func testProgrammeDayIsZeroBeforeStartOrWithoutProfile() {
        XCTAssertEqual(engine.programmeDay(for: makeData(startDaysAgo: -3), asOf: now), 0)
        XCTAssertEqual(engine.programmeDay(for: .empty, asOf: now), 0)
    }

    func testStreakIgnoresUnfinishedToday() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [1, 2, 3])
        XCTAssertEqual(engine.streak(for: data, asOf: now), 3)

        complete(&data, daysAgo: [0])
        XCTAssertEqual(engine.streak(for: data, asOf: now), 4)
    }

    func testStreakBreaksOnGap() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [0, 1, 3, 4, 5])
        XCTAssertEqual(engine.streak(for: data, asOf: now), 2)
    }

    func testStreakDoesNotCountDaysBeforeProgrammeStart() {
        var data = makeData(startDaysAgo: 1)
        complete(&data, daysAgo: [0, 1, 2, 3])
        XCTAssertEqual(engine.streak(for: data, asOf: now), 2)
    }

    func testNewPatientIsOnTrack() {
        let summary = engine.summary(for: makeData(startDaysAgo: 0), asOf: now)
        XCTAssertEqual(summary.state, .onTrack)
        XCTAssertEqual(summary.streak, 0)
    }

    func testTwoMissedDaysIsAtRisk() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [3, 4, 5, 6, 7])
        XCTAssertEqual(engine.summary(for: data, asOf: now).state, .atRisk)
        XCTAssertEqual(engine.nudge(for: data, asOf: now).kind, .restartSmall)
    }

    func testLowWeeklyCompletionIsSlipping() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [1, 3, 5])
        let summary = engine.summary(for: data, asOf: now)
        XCTAssertEqual(summary.state, .slipping)
        XCTAssertEqual(summary.sevenDayCompletion, 3.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(engine.nudge(for: data, asOf: now).kind, .oneIsEnough)
    }

    func testOnlyPrescribedExercisesCount() {
        var data = makeData(startDaysAgo: 3)
        let day = daysAgo(1)
        data.checkIns = [DailyCheckIn(day: day, completedExerciseIDs: ["not-prescribed"])]
        XCTAssertEqual(engine.completion(on: day, in: data).completed, 0)
    }

    func testHighPainTakesPriorityOverEverything() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [1, 2, 3, 4, 5, 6])
        data.recordPain(8, on: now, calendar: calendar)
        let nudge = engine.nudge(for: data, asOf: now)
        XCTAssertEqual(nudge.kind, .highPain)
        XCTAssertTrue(nudge.message.contains("physio"))
    }

    func testHabitReversionWindowWhenPainDropsMidProgramme() {
        var data = makeData(startDaysAgo: 30, baselinePain: 6)
        complete(&data, daysAgo: [1, 2])
        data.recordPain(2, on: daysAgo(1), calendar: calendar)
        data.recordPain(3, on: daysAgo(2), calendar: calendar)
        XCTAssertTrue(engine.summary(for: data, asOf: now).inHabitReversionWindow)
        XCTAssertEqual(engine.nudge(for: data, asOf: now).kind, .habitReversion)
    }

    func testNoHabitReversionWindowAfterProgrammeEnds() {
        var data = makeData(startDaysAgo: 100, baselinePain: 6)
        data.recordPain(1, on: daysAgo(1), calendar: calendar)
        XCTAssertFalse(engine.summary(for: data, asOf: now).inHabitReversionWindow)
    }

    func testNoHabitReversionWindowWhenBaselinePainWasLow() {
        var data = makeData(startDaysAgo: 30, baselinePain: 2)
        data.recordPain(1, on: daysAgo(1), calendar: calendar)
        XCTAssertFalse(engine.summary(for: data, asOf: now).inHabitReversionWindow)
    }

    func testStreakMilestoneEveryThirdDay() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [0, 1, 2, 3, 4, 5])
        let nudge = engine.nudge(for: data, asOf: now)
        XCTAssertEqual(nudge.kind, .streakMilestone)
        XCTAssertEqual(nudge.title, "6 days in a row")
    }

    func testDefaultNudgeUsesPatientsOwnGoal() {
        var data = makeData(startDaysAgo: 10)
        complete(&data, daysAgo: [0, 1, 2, 3, 4])
        let nudge = engine.nudge(for: data, asOf: now)
        XCTAssertEqual(nudge.kind, .keepGoing)
        XCTAssertTrue(nudge.message.contains("surfing"))
    }

    func testRecentDaysAreOldestFirstAndEndToday() {
        let days = engine.recentDays(7, in: makeData(startDaysAgo: 10), asOf: now)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.day, calendar.startOfDay(for: now))
        XCTAssertEqual(days.first?.day, daysAgo(6))
    }

    // MARK: - Helpers

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: now))!
    }

    private func makeData(startDaysAgo: Int, baselinePain: Int = 5) -> AppData {
        AppData(
            profile: PatientProfile(
                preferredName: "Test",
                recoveryGoal: "surfing",
                programmeStartDate: daysAgo(startDaysAgo),
                baselinePain: baselinePain
            ),
            consent: ConsentRecord(grantedAt: daysAgo(startDaysAgo), scopes: [.coreProgramme])
        )
    }

    private func complete(_ data: inout AppData, daysAgo offsets: [Int]) {
        for offset in offsets {
            for id in allIDs {
                data.toggleExercise(id, on: daysAgo(offset), calendar: calendar)
            }
        }
    }
}
