import Foundation

/// On-device retention rules. See ios/docs/DATA_GOVERNANCE.md §8.
public struct DataRetentionPolicy: Sendable {
    public var checkInRetentionDays: Int

    public init(checkInRetentionDays: Int) {
        self.checkInRetentionDays = checkInRetentionDays
    }

    public static let standard = DataRetentionPolicy(checkInRetentionDays: 365)

    /// Removes check-ins older than the retention window.
    public func apply(to data: AppData, asOf now: Date, calendar: Calendar) -> AppData {
        guard let cutoff = calendar.date(byAdding: .day, value: -checkInRetentionDays, to: calendar.startOfDay(for: now)) else {
            return data
        }
        var copy = data
        copy.checkIns.removeAll { $0.day < cutoff }
        return copy
    }
}

/// Builds the patient's copy of their data (right of access, HIPC 2020 rule 6).
public enum PersonalDataExport {
    public struct Envelope: Codable, Sendable {
        public let format: String
        public let exportedAt: Date
        public let data: AppData
    }

    public static let formatName = "RehabPath personal data export v1"

    public static func makeJSON(from data: AppData, exportedAt: Date) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Envelope(format: formatName, exportedAt: exportedAt, data: data))
    }

    public static func decode(_ json: Data) throws -> Envelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Envelope.self, from: json)
    }
}
