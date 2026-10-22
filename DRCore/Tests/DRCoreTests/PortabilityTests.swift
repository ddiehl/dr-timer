import XCTest
@testable import DRCore

/// Pins the wire format of a Flight so the future Watch transfer format
/// cannot drift silently.
final class PortabilityTests: XCTestCase {
    func testFlightEncodesToStableJSONKeys() throws {
        let flight = Flight(name: "Test", legs: [Leg(landmark: "Bridge", seconds: 90)])
        let data = try JSONEncoder().encode(flight)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "name", "legs"])
        let legs = try XCTUnwrap(object["legs"] as? [[String: Any]])
        XCTAssertEqual(legs.count, 1)
        XCTAssertEqual(Set(legs[0].keys), ["id", "landmark", "seconds"])
        XCTAssertEqual(object["name"] as? String, "Test")
        XCTAssertEqual(legs[0]["landmark"] as? String, "Bridge")
        XCTAssertEqual(legs[0]["seconds"] as? Int, 90)
    }
}
