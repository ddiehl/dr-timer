import XCTest
@testable import DRCore

final class StoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func sampleFlight() -> Flight {
        Flight(name: "Test", legs: [Leg(landmark: "A", seconds: 90), Leg(landmark: "B", seconds: 120)])
    }

    func testLoadAllMissingFileReturnsEmpty() throws {
        let repo = FlightRepository(fileURL: dir.appendingPathComponent("flights.json"))
        XCTAssertEqual(try repo.loadAll(), [])
    }

    func testLoadAllCorruptFileThrows() throws {
        let url = dir.appendingPathComponent("flights.json")
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try FlightRepository(fileURL: url).loadAll())
    }

    func testSaveThenLoadAllRoundTrips() throws {
        let url = dir.appendingPathComponent("flights.json")
        let flights = [sampleFlight(), Flight(name: "Other", legs: [Leg(landmark: "C", seconds: 30)])]
        try FlightRepository(fileURL: url).save(flights)
        XCTAssertEqual(try FlightRepository(fileURL: url).loadAll(), flights)
    }

    func testRunStoreRoundTripPreservesCountingEndDate() throws {
        let store = RunStore(fileURL: dir.appendingPathComponent("run.json"))
        var run = FlightRun(flight: sampleFlight())
        run.advance(at: Date(timeIntervalSince1970: 1_700_000_000.123456))
        try store.save(run)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded, run)
        XCTAssertEqual(loaded.phase, run.phase)
    }

    func testRunStoreCorruptFileReturnsNil() throws {
        let url = dir.appendingPathComponent("run.json")
        try Data("not json {".utf8).write(to: url)
        XCTAssertNil(RunStore(fileURL: url).load())
    }

    func testRunStoreClearRemovesFile() throws {
        let url = dir.appendingPathComponent("run.json")
        let store = RunStore(fileURL: url)
        try store.save(FlightRun(flight: sampleFlight()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(store.load())
    }
}
