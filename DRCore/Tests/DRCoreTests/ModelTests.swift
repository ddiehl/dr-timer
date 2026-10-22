import XCTest
@testable import DRCore

final class ModelTests: XCTestCase {
    func testLegValidRange() {
        XCTAssertTrue(Leg(landmark: "A", seconds: 1).isValid)
        XCTAssertTrue(Leg(landmark: "A", seconds: 5999).isValid)
        XCTAssertFalse(Leg(landmark: "A", seconds: 0).isValid)
        XCTAssertFalse(Leg(landmark: "A", seconds: 6000).isValid)
    }

    func testLegBlankLandmarkInvalid() {
        XCTAssertFalse(Leg(landmark: "", seconds: 60).isValid)
        XCTAssertFalse(Leg(landmark: "   ", seconds: 60).isValid)
    }

    func testFlightNeedsAtLeastOneLeg() {
        XCTAssertFalse(Flight(name: "F", legs: []).isValid)
        XCTAssertTrue(Flight(name: "F", legs: [Leg(landmark: "A", seconds: 60)]).isValid)
    }

    func testFlightTotalSeconds() {
        let f = Flight(name: "F", legs: [Leg(landmark: "A", seconds: 750), Leg(landmark: "B", seconds: 1080)])
        XCTAssertEqual(f.totalSeconds, 1830)
    }

    func testMmssFormatting() {
        XCTAssertEqual(TimeFormat.mmss(750), "12:30")
        XCTAssertEqual(TimeFormat.mmss(5), "00:05")
        XCTAssertEqual(TimeFormat.mmss(5999), "99:59")
    }

    func testParseMinutesSeconds() {
        XCTAssertEqual(TimeFormat.parse(minutes: "12", seconds: "30"), 750)
        XCTAssertNil(TimeFormat.parse(minutes: "0", seconds: "0"))
        XCTAssertNil(TimeFormat.parse(minutes: "100", seconds: "0"))
        XCTAssertNil(TimeFormat.parse(minutes: "12", seconds: "75"))
        XCTAssertNil(TimeFormat.parse(minutes: "", seconds: "30"))
        XCTAssertNil(TimeFormat.parse(minutes: "a", seconds: "30"))
    }

    func testFlightCodableRoundTrip() throws {
        let f = Flight(name: "F", legs: [Leg(landmark: "A", seconds: 750), Leg(landmark: "B", seconds: 1080)])
        let data = try JSONEncoder().encode(f)
        XCTAssertEqual(try JSONDecoder().decode(Flight.self, from: data), f)
    }
}
