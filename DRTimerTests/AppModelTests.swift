import XCTest
import DRCore
@testable import DRTimer

final class AppModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeModel() -> AppModel {
        AppModel(repository: FlightRepository(fileURL: dir.appendingPathComponent("flights.json")),
                 runStore: RunStore(fileURL: dir.appendingPathComponent("run.json")))
    }

    private func sample() -> Flight {
        Flight(name: "Practice", legs: [Leg(landmark: "Bridge", seconds: 750),
                                        Leg(landmark: "Tower", seconds: 300)])
    }

    func testAddPersistsAcrossReload() {
        let flight = sample()
        makeModel().addFlight(flight)
        XCTAssertEqual(makeModel().flights, [flight])
    }

    func testDeleteRemoves() {
        let model = makeModel()
        let flight = sample()
        model.addFlight(flight)
        model.deleteFlight(id: flight.id)
        XCTAssertTrue(model.flights.isEmpty)
        XCTAssertTrue(makeModel().flights.isEmpty)
    }

    func testDuplicateCreatesNewIdAndSameLegs() {
        let model = makeModel()
        let flight = sample()
        model.addFlight(flight)
        model.duplicateFlight(id: flight.id)
        XCTAssertEqual(model.flights.count, 2)
        let copy = model.flights[1]
        XCTAssertNotEqual(copy.id, flight.id)
        XCTAssertEqual(copy.legs.map(\.landmark), flight.legs.map(\.landmark))
        XCTAssertEqual(copy.legs.map(\.seconds), flight.legs.map(\.seconds))
    }

    func testUpdateReplacesFlight() {
        let model = makeModel()
        var flight = sample()
        model.addFlight(flight)
        flight.name = "Renamed"
        model.updateFlight(flight)
        XCTAssertEqual(makeModel().flights.first?.name, "Renamed")
    }
}
