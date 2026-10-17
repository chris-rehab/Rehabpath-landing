import Foundation

/// Granular, purpose-specific consent. See ios/docs/DATA_GOVERNANCE.md §5.
public enum ConsentScope: String, Codable, CaseIterable, Sendable {
    /// Store the programme, profile and daily check-ins on this device. Required to use the app.
    case coreProgramme
    /// One daily local notification. No health details are shown in the notification.
    case reminders
    /// Allow the people the patient picks in Care team to see progress (not transmitted in the prototype).
    case shareWithCareTeam
    /// Allow de-identified, aggregated use for research (not transmitted in the prototype).
    case aggregateResearch

    public var isRequired: Bool { self == .coreProgramme }

    /// Privacy-protective defaults: only reminders are pre-selected among optional scopes,
    /// because they never move data off the device.
    public static let defaultOptionalScopes: Set<ConsentScope> = [.reminders]
}

public struct ConsentRecord: Codable, Hashable, Sendable {
    /// Bump whenever the consent wording or data use changes; patients must re-consent.
    public static let currentVersion = "2026-10-prototype.1"

    public var version: String
    public var grantedAt: Date
    public var scopes: Set<ConsentScope>

    public init(version: String = ConsentRecord.currentVersion, grantedAt: Date, scopes: Set<ConsentScope>) {
        self.version = version
        self.grantedAt = grantedAt
        self.scopes = scopes
    }

    public var isCurrent: Bool { version == Self.currentVersion }

    public func allows(_ scope: ConsentScope) -> Bool { scopes.contains(scope) }

    /// Returns a copy with an optional scope granted or withdrawn. Core consent cannot be
    /// toggled here — withdrawing it means deleting all data.
    public func setting(_ scope: ConsentScope, granted: Bool) -> ConsentRecord {
        guard !scope.isRequired else { return self }
        var copy = self
        if granted {
            copy.scopes.insert(scope)
        } else {
            copy.scopes.remove(scope)
        }
        return copy
    }
}
