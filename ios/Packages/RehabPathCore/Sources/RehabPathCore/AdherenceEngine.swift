import Foundation

/// Patient-facing adherence state. Mirrors the founder dashboard's green/amber/red states,
/// but is never shown to the patient as a colour or a "fail" label (see UX_PRINCIPLES.md).
public enum AdherenceState: String, Codable, Sendable {
    case onTrack
    case slipping
    case atRisk
}

public struct DayCompletion: Identifiable, Hashable, Sendable {
    public let day: Date
    public let completed: Int
    public let total: Int

    public var id: Date { day }
    public var rate: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}

public struct AdherenceSummary: Hashable, Sendable {
    public let state: AdherenceState
    public let streak: Int
    /// Share of prescribed exercises completed over the last seven full days (0–1).
    public let sevenDayCompletion: Double
    /// 1-based day of the programme; 0 before it starts.
    public let programmeDay: Int
    public let inHabitReversionWindow: Bool
    public let latestPain: Int?
}

public struct Nudge: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case highPain
        case habitReversion
        case restartSmall
        case oneIsEnough
        case streakMilestone
        case keepGoing
    }

    public let kind: Kind
    public let title: String
    public let message: String
}

/// Rules-based behavioural engine. Deterministic and explainable by design: every nudge
/// can be traced to a documented rule. It never changes the prescribed programme.
public struct AdherenceEngine: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func programmeDay(for data: AppData, asOf now: Date) -> Int {
        guard let start = data.profile?.programmeStartDate else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0
        return days < 0 ? 0 : days + 1
    }

    public func completion(on date: Date, in data: AppData) -> DayCompletion {
        let day = calendar.startOfDay(for: date)
        let prescribed = Set(data.programme.exercises.map(\.id))
        let done = data.checkIn(on: day, calendar: calendar)?.completedExerciseIDs.intersection(prescribed).count ?? 0
        return DayCompletion(day: day, completed: done, total: prescribed.count)
    }

    /// The last `count` days ending today, oldest first.
    public func recentDays(_ count: Int, in data: AppData, asOf now: Date) -> [DayCompletion] {
        (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))
        }.map { completion(on: $0, in: data) }
    }

    /// Consecutive days with at least one exercise done. Today only counts once something is done,
    /// so an unfinished today never breaks the streak.
    public func streak(for data: AppData, asOf now: Date) -> Int {
        guard let startDate = data.profile?.programmeStartDate else { return 0 }
        let start = calendar.startOfDay(for: startDate)
        var day = calendar.startOfDay(for: now)
        if completion(on: day, in: data).completed == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while day >= start, completion(on: day, in: data).completed > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    public func summary(for data: AppData, asOf now: Date) -> AdherenceSummary {
        let day = programmeDay(for: data, asOf: now)
        let fullDays = pastFullDays(in: data, asOf: now, limit: 7)
        let sevenDay: Double = {
            let total = fullDays.reduce(0) { $0 + $1.total }
            return total == 0 ? 1 : Double(fullDays.reduce(0) { $0 + $1.completed }) / Double(total)
        }()

        let state: AdherenceState
        if fullDays.count >= 2, fullDays.suffix(2).allSatisfy({ $0.completed == 0 }) {
            state = .atRisk
        } else if !fullDays.isEmpty, sevenDay < 0.5 {
            state = .slipping
        } else {
            state = .onTrack
        }

        return AdherenceSummary(
            state: state,
            streak: streak(for: data, asOf: now),
            sevenDayCompletion: sevenDay,
            programmeDay: day,
            inHabitReversionWindow: inHabitReversionWindow(data, asOf: now, programmeDay: day),
            latestPain: latestPain(in: data, asOf: now)
        )
    }

    public func nudge(for data: AppData, asOf now: Date) -> Nudge {
        let summary = self.summary(for: data, asOf: now)
        let goal = Self.midSentence(data.profile?.recoveryGoal ?? "your goal")

        if let pain = summary.latestPain, pain >= PainScale.contactPhysioThreshold {
            return Nudge(
                kind: .highPain,
                title: "Check in with your physio",
                message: "Pain at this level is worth talking to your physio about before you push on. Only do what feels manageable today."
            )
        }
        if summary.inHabitReversionWindow {
            return Nudge(
                kind: .habitReversion,
                title: "Feeling better? Keep going",
                message: "Less pain is great news — and it's when most people stop. Your body is still rebuilding strength for \(goal)."
            )
        }
        switch summary.state {
        case .atRisk:
            return Nudge(
                kind: .restartSmall,
                title: "Restart small",
                message: "Missing a few days happens to everyone. Pick just one exercise today — that's a restart."
            )
        case .slipping:
            return Nudge(
                kind: .oneIsEnough,
                title: "One is better than none",
                message: "Busy week? Even one exercise keeps the habit alive."
            )
        case .onTrack:
            if summary.streak >= 3, summary.streak % 3 == 0 {
                return Nudge(
                    kind: .streakMilestone,
                    title: "\(summary.streak) days in a row",
                    message: "You've shown up \(summary.streak) days running. That's how habits are built."
                )
            }
            return Nudge(
                kind: .keepGoing,
                title: "Today counts",
                message: "Every session today is a step towards \(goal)."
            )
        }
    }

    // MARK: - Rules

    /// The patient's goal as it reads inside a sentence: "Walking the dog" becomes "walking the
    /// dog", while an acronym such as "ACL rehab" keeps its capitals.
    static func midSentence(_ goal: String) -> String {
        guard let first = goal.first, first.isUppercase else { return goal }
        if let second = goal.dropFirst().first, second.isUppercase { return goal }
        return first.lowercased() + goal.dropFirst()
    }

    /// Completed days before today that fall within the programme, oldest first.
    private func pastFullDays(in data: AppData, asOf now: Date, limit: Int) -> [DayCompletion] {
        let elapsed = max(programmeDay(for: data, asOf: now) - 1, 0)
        let count = min(elapsed, limit)
        guard count > 0, let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return []
        }
        return recentDays(count, in: data, asOf: yesterday)
    }

    private func latestPain(in data: AppData, asOf now: Date) -> Int? {
        let today = calendar.startOfDay(for: now)
        return data.checkIns.filter { $0.day <= today && $0.painScore != nil }.max { $0.day < $1.day }?.painScore
    }

    /// Pain has dropped substantially but the programme isn't finished — the point where
    /// adherence typically collapses (see the landing page's evidence summary).
    private func inHabitReversionWindow(_ data: AppData, asOf now: Date, programmeDay: Int) -> Bool {
        guard let baseline = data.profile?.baselinePain, baseline >= 4,
              programmeDay > 0, programmeDay <= data.programme.lengthInDays,
              let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        else { return false }
        let recent = data.checkIns.filter { $0.day >= weekAgo && $0.day <= now }.compactMap(\.painScore)
        guard !recent.isEmpty else { return false }
        let average = Double(recent.reduce(0, +)) / Double(recent.count)
        return average <= 3
    }
}
