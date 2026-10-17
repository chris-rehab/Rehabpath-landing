import Foundation

extension AppData {
    /// Synthetic, onboarded data for previews, UI tests and App Store screenshots.
    /// Never replace with real patient data (DATA_GOVERNANCE.md §7.6).
    public static func sample(asOf now: Date, calendar: Calendar) -> AppData {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -20, to: today) ?? today
        let ids = Programme.sampleKnee.exercises.map(\.id)

        var checkIns: [DailyCheckIn] = (1...6).compactMap { offset -> DailyCheckIn? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let done = offset == 4 ? Array(ids.prefix(2)) : ids
            return DailyCheckIn(day: day, completedExerciseIDs: Set(done), painScore: max(6 - offset / 2, 3))
        }
        checkIns.append(DailyCheckIn(day: today, completedExerciseIDs: Set(ids.prefix(2))))

        var careTeam = CareTeamMember.samples
        careTeam[0].isSharing = true

        return AppData(
            profile: PatientProfile(
                preferredName: "Aroha",
                recoveryGoal: "playing netball again",
                programmeStartDate: start,
                baselinePain: 6
            ),
            consent: ConsentRecord(grantedAt: start, scopes: [.coreProgramme, .reminders, .shareWithCareTeam]),
            checkIns: checkIns.sorted { $0.day < $1.day },
            careTeam: careTeam
        )
    }
}
