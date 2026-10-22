import XCTest
import DRCore
@testable import DRTimer

private final class FakeClock: Clock {
    var now: Date
    init(_ now: Date = Date(timeIntervalSince1970: 1_000_000)) { self.now = now }
    func advance(_ s: TimeInterval) { now = now.addingTimeInterval(s) }
}

private final class RecordingAlerts: AlertControlling {
    var events: [String] = []
    var scheduled: [(Date, String)] = []
    func scheduleTimeUp(at: Date, landmark: String) { scheduled.append((at, landmark)); events.append("schedule") }
    func startRinging() { events.append("start") }
    func stopRinging() { events.append("stop") }
    func cancelScheduled() { events.append("cancel") }
    func count(_ e: String) -> Int { events.filter { $0 == e }.count }
}

final class RunViewModelTests: XCTestCase {
    private var dir: URL!
    private var store: RunStore!
    private var clock: FakeClock!
    private var alerts: RecordingAlerts!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = RunStore(fileURL: dir.appendingPathComponent("run.json"))
        clock = FakeClock()
        alerts = RecordingAlerts()
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func flight() -> Flight {
        Flight(name: "T", legs: [Leg(landmark: "Bridge", seconds: 60), Leg(landmark: "Tower", seconds: 30)])
    }

    private func makeVM() -> RunViewModel {
        RunViewModel(run: FlightRun(flight: flight()), store: store, clock: clock, alerts: alerts)
    }

    func testTapStartsCountdownAndSchedulesAlert() {
        let vm = makeVM()
        vm.primaryTapped()
        XCTAssertEqual(vm.run.phase, .counting(leg: 0, endsAt: clock.now.addingTimeInterval(60)))
        XCTAssertEqual(vm.remainingSeconds, 60)
        XCTAssertEqual(alerts.scheduled.count, 1)
        XCTAssertEqual(alerts.scheduled[0].0, clock.now.addingTimeInterval(60))
        XCTAssertEqual(alerts.scheduled[0].1, "Bridge")
    }

    func testRefreshAfterEndEntersTimeUpAndStartsRinging() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(59); vm.refresh()
        XCTAssertEqual(vm.remainingSeconds, 1)
        XCTAssertEqual(alerts.count("start"), 0)
        clock.advance(1); vm.refresh()
        XCTAssertEqual(vm.run.phase, .timeUp(leg: 0))
        XCTAssertEqual(vm.remainingSeconds, 0)
        XCTAssertEqual(alerts.count("start"), 1)
    }

    func testRingingStartedOnlyOnce() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(100)
        vm.refresh(); vm.refresh(); vm.refresh()
        XCTAssertEqual(alerts.count("start"), 1)
    }

    func testTapOnTimeUpStopsRingingAndStartsNextLeg() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(60); vm.refresh()
        alerts.events.removeAll()
        vm.primaryTapped()
        XCTAssertEqual(alerts.count("stop"), 1)
        XCTAssertEqual(vm.run.phase, .counting(leg: 1, endsAt: clock.now.addingTimeInterval(30)))
        XCTAssertEqual(alerts.scheduled.last?.1, "Tower")
        // the next time-up rings again
        clock.advance(30); vm.refresh()
        XCTAssertEqual(alerts.count("start"), 1)
    }

    func testFinishClearsStoredRun() {
        let vm = makeVM()
        vm.primaryTapped(); clock.advance(60); vm.refresh()
        vm.primaryTapped(); clock.advance(30); vm.refresh()
        XCTAssertNotNil(store.load())
        alerts.events.removeAll()
        vm.primaryTapped()
        XCTAssertEqual(vm.run.phase, .finished)
        XCTAssertNil(store.load())
        XCTAssertEqual(alerts.count("stop"), 1)
        XCTAssertEqual(alerts.count("schedule"), 0)
    }

    func testRestoreMidCountingResumesRemaining() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(20)
        let a2 = RecordingAlerts()
        let restored = RunViewModel.restoreIfAny(store: store, clock: clock, alerts: a2)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.remainingSeconds, 40)
        XCTAssertEqual(a2.scheduled.count, 1)
        XCTAssertEqual(a2.scheduled.first?.0, Date(timeIntervalSince1970: 1_000_060))
        XCTAssertEqual(a2.scheduled.first?.1, "Bridge")
        XCTAssertEqual(restored?.run.phase, .counting(leg: 0, endsAt: Date(timeIntervalSince1970: 1_000_060)))
    }

    func testRestoreAfterEndDatePassedShowsTimeUpAndRings() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(500)
        let a2 = RecordingAlerts()
        let restored = RunViewModel.restoreIfAny(store: store, clock: clock, alerts: a2)
        XCTAssertEqual(restored?.run.phase, .timeUp(leg: 0))
        XCTAssertEqual(a2.count("start"), 1)
        XCTAssertEqual(a2.count("schedule"), 0)
        restored?.refresh()
        XCTAssertEqual(a2.count("start"), 1)
    }

    func testRestoreWithNothingSavedReturnsNil() {
        XCTAssertNil(RunViewModel.restoreIfAny(store: store, clock: clock, alerts: alerts))
    }

    func testPrimaryTapIgnoredWhileCounting() {
        let vm = makeVM()
        vm.primaryTapped()
        let phase = vm.run.phase
        alerts.events.removeAll()
        clock.advance(10)
        vm.primaryTapped()
        XCTAssertEqual(vm.run.phase, phase)
        XCTAssertTrue(alerts.events.isEmpty)
    }

    func testEndFlightIgnoredWhileCounting() {
        let vm = makeVM()
        vm.primaryTapped()
        vm.endFlightConfirmed()
        XCTAssertEqual(vm.run.phase, .counting(leg: 0, endsAt: clock.now.addingTimeInterval(60)))
        XCTAssertNotNil(store.load())
    }

    func testEndFlightFromReadyAndTimeUpFinishesAndClears() {
        let vm = makeVM()
        vm.primaryTapped(); clock.advance(60); vm.refresh()
        alerts.events.removeAll()
        vm.endFlightConfirmed()
        XCTAssertEqual(vm.run.phase, .finished)
        XCTAssertNil(store.load())
        XCTAssertEqual(alerts.count("stop"), 1)
    }

    func testRunSavedAfterEveryTransition() {
        let vm = makeVM()
        vm.primaryTapped()
        XCTAssertEqual(store.load()?.phase, vm.run.phase)
        clock.advance(60); vm.refresh()
        XCTAssertEqual(store.load()?.phase, .timeUp(leg: 0))
        vm.primaryTapped()
        XCTAssertEqual(store.load()?.phase, vm.run.phase)
    }

    func testPauseCancelsAlertAndFreezesTime() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(20)
        alerts.events.removeAll()
        vm.pauseTapped()
        XCTAssertEqual(vm.run.phase, .paused(leg: 0, remaining: 40))
        XCTAssertEqual(alerts.events, ["cancel"])
        clock.advance(500)
        vm.refresh()
        XCTAssertEqual(vm.remainingSeconds, 40)
        XCTAssertEqual(alerts.count("start"), 0)
    }

    func testResumeReschedulesAlertWithRemainingTime() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(20)
        vm.pauseTapped()
        clock.advance(100)
        vm.resumeTapped()
        XCTAssertEqual(vm.run.phase, .counting(leg: 0, endsAt: clock.now.addingTimeInterval(40)))
        XCTAssertEqual(alerts.scheduled.last?.0, clock.now.addingTimeInterval(40))
        XCTAssertEqual(alerts.scheduled.last?.1, "Bridge")
    }

    func testNextLegStartsNextCountdownAndReschedules() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(10)
        vm.nextLegTapped()
        XCTAssertEqual(vm.run.phase, .counting(leg: 1, endsAt: clock.now.addingTimeInterval(30)))
        XCTAssertEqual(alerts.scheduled.last?.1, "Tower")
        XCTAssertEqual(vm.remainingSeconds, 30)
    }

    func testNextLegOnLastLegFinishesAndClears() {
        let vm = makeVM()
        vm.primaryTapped()
        vm.nextLegTapped()
        vm.nextLegTapped()
        XCTAssertEqual(vm.run.phase, .finished)
        XCTAssertNil(store.load())
    }

    func testPausedRunRestoresPaused() {
        let vm = makeVM()
        vm.primaryTapped()
        clock.advance(20)
        vm.pauseTapped()
        clock.advance(1000)
        let restored = RunViewModel.restoreIfAny(store: store, clock: clock, alerts: alerts)
        XCTAssertEqual(restored?.run.phase, .paused(leg: 0, remaining: 40))
        XCTAssertEqual(restored?.remainingSeconds, 40)
    }
}
