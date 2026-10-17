import Foundation

// Every field stored here is listed in ios/docs/DATA_GOVERNANCE.md (data inventory).
// Adding or changing a field requires updating that inventory first.

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var focus: String
    public var sets: Int
    public var reps: Int

    public init(id: String, name: String, focus: String, sets: Int, reps: Int) {
        self.id = id
        self.name = name
        self.focus = focus
        self.sets = sets
        self.reps = reps
    }

    /// Display form, e.g. "3 × 15".
    public var prescription: String { "\(sets) × \(reps)" }
}

public struct Programme: Codable, Hashable, Sendable {
    public var title: String
    public var lengthInDays: Int
    public var exercises: [Exercise]

    public init(title: String, lengthInDays: Int, exercises: [Exercise]) {
        self.title = title
        self.lengthInDays = lengthInDays
        self.exercises = exercises
    }

    /// Synthetic sample programme. Prototype only — not clinical advice.
    public static let sampleKnee = Programme(
        title: "Knee strengthening",
        lengthInDays: 84,
        exercises: [
            Exercise(id: "quad-sets", name: "Quad sets", focus: "Isometric strengthening", sets: 3, reps: 15),
            Exercise(id: "straight-leg-raises", name: "Straight leg raises", focus: "Quad activation", sets: 3, reps: 12),
            Exercise(id: "mini-squats", name: "Mini squats", focus: "Functional loading", sets: 3, reps: 10),
            Exercise(id: "step-ups", name: "Step-ups", focus: "Balance and control", sets: 2, reps: 15),
            Exercise(id: "bridges", name: "Glute bridges", focus: "Hip strength", sets: 3, reps: 10)
        ]
    )
}

public struct PatientProfile: Codable, Hashable, Sendable {
    public var preferredName: String
    /// The patient's own words for what they want to get back to (their "identity anchor").
    public var recoveryGoal: String
    public var programmeStartDate: Date
    /// Self-reported pain at onboarding, 0–10.
    public var baselinePain: Int

    public init(preferredName: String, recoveryGoal: String, programmeStartDate: Date, baselinePain: Int) {
        self.preferredName = preferredName
        self.recoveryGoal = recoveryGoal
        self.programmeStartDate = programmeStartDate
        self.baselinePain = PainScale.clamp(baselinePain)
    }
}

public enum PainScale {
    public static let range = 0...10

    public static func clamp(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Scores at or above this prompt the patient to contact their physio.
    public static let contactPhysioThreshold = 7
}

public struct DailyCheckIn: Codable, Identifiable, Hashable, Sendable {
    /// Start of the local day this check-in belongs to.
    public var day: Date
    public var completedExerciseIDs: Set<String>
    public var painScore: Int?

    public var id: Date { day }

    public init(day: Date, completedExerciseIDs: Set<String> = [], painScore: Int? = nil) {
        self.day = day
        self.completedExerciseIDs = completedExerciseIDs
        self.painScore = painScore.map(PainScale.clamp)
    }
}

public struct CareTeamMember: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var role: String
    public var organisation: String
    public var isSharing: Bool

    public init(id: UUID = UUID(), name: String, role: String, organisation: String, isSharing: Bool = false) {
        self.id = id
        self.name = name
        self.role = role
        self.organisation = organisation
        self.isSharing = isSharing
    }

    /// Fictional people for the prototype. Sharing is off by default.
    public static let samples: [CareTeamMember] = [
        CareTeamMember(name: "Sam Taylor", role: "Physiotherapist", organisation: "Example Physio Clinic"),
        CareTeamMember(name: "Dr Alex Morgan", role: "Orthopaedic surgeon", organisation: "Example Hospital"),
        CareTeamMember(name: "Jordan Lee", role: "Personal trainer", organisation: "Return-to-fitness programme")
    ]
}

public struct AppData: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var profile: PatientProfile?
    public var consent: ConsentRecord?
    public var programme: Programme
    public var checkIns: [DailyCheckIn]
    public var careTeam: [CareTeamMember]

    public init(
        schemaVersion: Int = AppData.currentSchemaVersion,
        profile: PatientProfile? = nil,
        consent: ConsentRecord? = nil,
        programme: Programme = .sampleKnee,
        checkIns: [DailyCheckIn] = [],
        careTeam: [CareTeamMember] = CareTeamMember.samples
    ) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.consent = consent
        self.programme = programme
        self.checkIns = checkIns
        self.careTeam = careTeam
    }

    public static var empty: AppData { AppData() }

    /// The app may only show the programme once the patient has a profile and current core consent.
    public var isOnboarded: Bool {
        profile != nil && consent?.isCurrent == true && consent?.allows(.coreProgramme) == true
    }
}

// MARK: - Check-in mutations

extension AppData {
    public func checkIn(on date: Date, calendar: Calendar) -> DailyCheckIn? {
        let day = calendar.startOfDay(for: date)
        return checkIns.first { $0.day == day }
    }

    public mutating func toggleExercise(_ exerciseID: String, on date: Date, calendar: Calendar) {
        guard programme.exercises.contains(where: { $0.id == exerciseID }) else { return }
        updateCheckIn(on: date, calendar: calendar) { checkIn in
            if checkIn.completedExerciseIDs.contains(exerciseID) {
                checkIn.completedExerciseIDs.remove(exerciseID)
            } else {
                checkIn.completedExerciseIDs.insert(exerciseID)
            }
        }
    }

    public mutating func recordPain(_ score: Int, on date: Date, calendar: Calendar) {
        updateCheckIn(on: date, calendar: calendar) { $0.painScore = PainScale.clamp(score) }
    }

    private mutating func updateCheckIn(on date: Date, calendar: Calendar, _ change: (inout DailyCheckIn) -> Void) {
        let day = calendar.startOfDay(for: date)
        if let index = checkIns.firstIndex(where: { $0.day == day }) {
            change(&checkIns[index])
        } else {
            var checkIn = DailyCheckIn(day: day)
            change(&checkIn)
            checkIns.append(checkIn)
            checkIns.sort { $0.day < $1.day }
        }
    }
}
