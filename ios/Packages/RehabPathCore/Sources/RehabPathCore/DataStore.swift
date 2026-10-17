import Foundation

public protocol DataStore: Sendable {
    func load() throws -> AppData
    func save(_ data: AppData) throws
    func deleteAll() throws
}

public enum DataStoreError: Error, Equatable {
    /// The file was written by a newer app version; refuse to overwrite it.
    case unsupportedSchema(Int)
}

/// Stores all patient data as a single JSON file.
///
/// On iOS the file is written with complete file protection (encrypted while the device is
/// locked) and excluded from iCloud/iTunes backup. See DATA_GOVERNANCE.md §7.
public struct FileDataStore: DataStore {
    public let fileURL: URL

    public init(directory: URL, fileName: String = "rehabpath-data.json") {
        self.fileURL = directory.appendingPathComponent(fileName)
    }

    public func load() throws -> AppData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try decoder.decode(AppData.self, from: Data(contentsOf: fileURL))
        guard data.schemaVersion <= AppData.currentSchemaVersion else {
            throw DataStoreError.unsupportedSchema(data.schemaVersion)
        }
        return data
    }

    public func save(_ data: AppData) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtection)
        #endif
        try encoder.encode(data).write(to: fileURL, options: options)
        try excludeFromBackup()
    }

    public func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func excludeFromBackup() throws {
        #if canImport(Darwin)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = fileURL
        try url.setResourceValues(values)
        #endif
    }
}

/// For tests, previews and UI-test launches. Nothing touches disk.
public final class InMemoryDataStore: DataStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppData?

    public init(_ initial: AppData? = nil) {
        stored = initial
    }

    public func load() throws -> AppData {
        lock.lock()
        defer { lock.unlock() }
        return stored ?? .empty
    }

    public func save(_ data: AppData) throws {
        lock.lock()
        defer { lock.unlock() }
        stored = data
    }

    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }
        stored = nil
    }

    public var hasData: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stored != nil
    }
}
