import XCTest
@testable import RehabPathCore

final class DataStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadWithoutFileReturnsEmpty() throws {
        XCTAssertEqual(try FileDataStore(directory: directory).load(), .empty)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = FileDataStore(directory: directory)
        let data = AppData.sample(asOf: TestCalendar.date(2026, 10, 17, hour: 9), calendar: TestCalendar.auckland)
        try store.save(data)
        XCTAssertEqual(try store.load(), data)
    }

    func testDeleteAllRemovesFile() throws {
        let store = FileDataStore(directory: directory)
        try store.save(.empty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        try store.deleteAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(try store.load(), .empty)
    }

    func testRefusesNewerSchema() throws {
        let store = FileDataStore(directory: directory)
        var data = AppData.empty
        data.schemaVersion = AppData.currentSchemaVersion + 1
        try store.save(data)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? DataStoreError, .unsupportedSchema(AppData.currentSchemaVersion + 1))
        }
    }

    func testInMemoryStore() throws {
        let store = InMemoryDataStore()
        XCTAssertFalse(store.hasData)
        try store.save(.empty)
        XCTAssertTrue(store.hasData)
        try store.deleteAll()
        XCTAssertFalse(store.hasData)
    }
}

enum TestCalendar {
    static let auckland: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        auckland.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
