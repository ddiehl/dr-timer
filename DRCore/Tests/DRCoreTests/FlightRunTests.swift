import XCTest
@testable import DRCore

final class FlightRunTests: XCTestCase {
    let T = Date(timeIntervalSince1970: 1_000_000)

    func makeRun() -> FlightRun {
        FlightRun(flight: Flight(name: "F", legs: [
            Leg(landmark: "A", seconds: 750),
            Leg(landmark: "B", seconds: 300),
        ]))
    }

    func testStartsReadyOnFirstLeg() {
        let r = makeRun()
        XCTAssertEqual(r.phase, .ready(leg: 0))
        XCTAssertEqual(r.currentLegIndex, 0)
        XCTAssertEqual(r.currentLeg?.landmark, "A")
        XCTAssertEqual(r.remaining(at: T), 0)
    }

    func testAdvanceFromReadyStartsCountdownWithAbsoluteEnd() {
        var r = makeRun()
        r.advance(at: T)
        XCTAssertEqual(r.phase, .counting(leg: 0, endsAt: T.addingTimeInterval(750)))
    }

    func testRemainingRoundsUpAndNeverNegative() {
        var r = makeRun()
        r.advance(at: T)
        XCTAssertEqual(r.remaining(at: T), 750)
        XCTAssertEqual(r.remaining(at: T.addingTimeInterval(749.8)), 1)
        XCTAssertEqual(r.remaining(at: T.addingTimeInterval(750)), 0)
        XCTAssertEqual(r.remaining(at: T.addingTimeInterval(9999)), 0)
    }

    func testTickBeforeEndKeepsCounting() {
        var r = makeRun()
        r.advance(at: T)
        r.tick(at: T.addingTimeInterval(749.9))
        XCTAssertEqual(r.phase, .counting(leg: 0, endsAt: T.addingTimeInterval(750)))
    }

    func testTickAtOrAfterEndGoesTimeUp() {
        var r = makeRun()
        r.advance(at: T)
        r.tick(at: T.addingTimeInterval(750))
        XCTAssertEqual(r.phase, .timeUp(leg: 0))
        var late = makeRun()
        late.advance(at: T)
        late.tick(at: T.addingTimeInterval(100_000))
        XCTAssertEqual(late.phase, .timeUp(leg: 0))
        XCTAssertEqual(late.remaining(at: T.addingTimeInterval(100_000)), 0)
    }

    func testAdvanceFromTimeUpStartsNextLegFromTapTimeNotPlannedTime() {
        var r = makeRun()
        r.advance(at: T)
        r.tick(at: T.addingTimeInterval(750))
        r.advance(at: T.addingTimeInterval(900))
        XCTAssertEqual(r.phase, .counting(leg: 1, endsAt: T.addingTimeInterval(900 + 300)))
    }

    func testAdvanceAfterLastLegFinishes() {
        var r = makeRun()
        r.advance(at: T)
        r.tick(at: T.addingTimeInterval(750))
        r.advance(at: T.addingTimeInterval(760))
        r.tick(at: T.addingTimeInterval(2000))
        XCTAssertEqual(r.phase, .timeUp(leg: 1))
        r.advance(at: T.addingTimeInterval(2001))
        XCTAssertEqual(r.phase, .finished)
        XCTAssertNil(r.currentLegIndex)
        XCTAssertNil(r.currentLeg)
        r.advance(at: T.addingTimeInterval(2002))
        XCTAssertEqual(r.phase, .finished)
    }

    func testIsLastLeg() {
        var r = makeRun()
        XCTAssertFalse(r.isLastLeg)
        r.advance(at: T)
        r.tick(at: T.addingTimeInterval(750))
        r.advance(at: T.addingTimeInterval(751))
        XCTAssertTrue(r.isLastLeg)
    }

    func testAdvanceWhileCountingIsNoOp() {
        var r = makeRun()
        r.advance(at: T)
        let before = r
        r.advance(at: T.addingTimeInterval(10))
        XCTAssertEqual(r, before)
    }

    func testEndFlightRefusedWhileCounting() {
        var r = makeRun()
        r.advance(at: T)
        r.endFlight()
        XCTAssertEqual(r.phase, .counting(leg: 0, endsAt: T.addingTimeInterval(750)))
    }

    func testEndFlightAllowedFromReadyAndTimeUp() {
        var a = makeRun()
        a.endFlight()
        XCTAssertEqual(a.phase, .finished)
        var b = makeRun()
        b.advance(at: T)
        b.tick(at: T.addingTimeInterval(750))
        b.endFlight()
        XCTAssertEqual(b.phase, .finished)
    }

    func testRunCodableRoundTripKeepsPhase() throws {
        var r = makeRun()
        r.advance(at: T)
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(FlightRun.self, from: data)
        XCTAssertEqual(back, r)
        XCTAssertEqual(back.phase, .counting(leg: 0, endsAt: T.addingTimeInterval(750)))
    }

    func testPauseFreezesRemainingAndResumeRestartsFromIt() {
        var r = makeRun()
        r.advance(at: T)
        r.pause(at: T.addingTimeInterval(100))
        XCTAssertEqual(r.phase, .paused(leg: 0, remaining: 650))
        XCTAssertEqual(r.remaining(at: T.addingTimeInterval(5000)), 650)
        r.tick(at: T.addingTimeInterval(5000))
        XCTAssertEqual(r.phase, .paused(leg: 0, remaining: 650))
        let t2 = T.addingTimeInterval(200)
        r.resume(at: t2)
        XCTAssertEqual(r.phase, .counting(leg: 0, endsAt: t2.addingTimeInterval(650)))
    }

    func testPauseOnlyWhileCounting() {
        var r = makeRun()
        r.pause(at: T)
        XCTAssertEqual(r.phase, .ready(leg: 0))
        r.resume(at: T)
        XCTAssertEqual(r.phase, .ready(leg: 0))
    }

    func testSkipFromCountingStartsNextLegNow() {
        var r = makeRun()
        r.advance(at: T)
        let t2 = T.addingTimeInterval(60)
        r.skipToNextLeg(at: t2)
        XCTAssertEqual(r.phase, .counting(leg: 1, endsAt: t2.addingTimeInterval(300)))
    }

    func testSkipFromPausedStartsNextLegNow() {
        var r = makeRun()
        r.advance(at: T)
        r.pause(at: T.addingTimeInterval(10))
        r.skipToNextLeg(at: T.addingTimeInterval(500))
        XCTAssertEqual(r.phase, .counting(leg: 1, endsAt: T.addingTimeInterval(800)))
    }

    func testSkipOnLastLegFinishes() {
        var r = makeRun()
        r.advance(at: T)
        r.skipToNextLeg(at: T)
        r.skipToNextLeg(at: T)
        XCTAssertEqual(r.phase, .finished)
    }

    func testSkipIgnoredWhenReady() {
        var r = makeRun()
        r.skipToNextLeg(at: T)
        XCTAssertEqual(r.phase, .ready(leg: 0))
    }
}
