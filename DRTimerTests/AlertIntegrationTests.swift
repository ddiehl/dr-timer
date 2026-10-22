import XCTest
import DRCore
@testable import DRTimer

private final class Audio: AudioPlaying {
    var playing: AlertSound?
    var alertPlays = 0
    func playLoop(_ sound: AlertSound) { playing = sound; if sound == .alert { alertPlays += 1 } }
    func stop() { playing = nil }
    func ensurePlaying() {}
}
private final class Buzz: Haptics { func pulse() {} }
private final class Notes: NotificationScheduling {
    var pending: [String: PendingNotification] = [:]
    func add(_ n: PendingNotification) { pending[n.id] = n }
    func remove(id: String) { pending[id] = nil }
    func requestAuthorization() {}
}
private final class Tmr: AlertTimer {
    let fire: Date?; let action: () -> Void; var cancelled = false
    init(_ fire: Date?, _ action: @escaping () -> Void) { self.fire = fire; self.action = action }
    func cancel() { cancelled = true }
}
private final class Timers: TimerScheduling {
    var all: [Tmr] = []
    var active: [Tmr] { all.filter { !$0.cancelled } }
    func schedule(at date: Date, _ action: @escaping () -> Void) -> AlertTimer {
        let t = Tmr(date, action); all.append(t); return t
    }
    func repeating(every interval: TimeInterval, _ action: @escaping () -> Void) -> AlertTimer {
        let t = Tmr(nil, action); all.append(t); return t
    }
}
private final class Clk: Clock {
    var now = Date(timeIntervalSince1970: 1_000_000)
}

final class AlertIntegrationTests: XCTestCase {
    private var dir: URL!
    private var audio: Audio!
    private var notes: Notes!
    private var timers: Timers!
    private var clock: Clk!
    private var vm: RunViewModel!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        audio = Audio(); notes = Notes(); timers = Timers(); clock = Clk()
        let alerts = AlertManager(audio: audio, haptics: Buzz(), notifications: notes, timers: timers)
        let flight = Flight(name: "T", legs: [Leg(landmark: "Bridge", seconds: 60)])
        vm = RunViewModel(run: FlightRun(flight: flight),
                          store: RunStore(fileURL: dir.appendingPathComponent("run.json")),
                          clock: clock, alerts: alerts)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func assertQuiet(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(audio.playing, file: file, line: line)
        XCTAssertTrue(notes.pending.isEmpty, file: file, line: line)
        XCTAssertTrue(timers.active.isEmpty, file: file, line: line)
    }

    func testStartTimeUpFinishLeavesNothingActive() {
        vm.primaryTapped()
        XCTAssertEqual(audio.playing, .keepAlive)
        XCTAssertEqual(notes.pending.count, 1)
        clock.now = clock.now.addingTimeInterval(60)
        timers.active.first { $0.fire != nil }?.action()   // end-time timer fires
        vm.refresh()
        XCTAssertEqual(audio.playing, .alert)
        vm.primaryTapped()                                  // FINISH
        XCTAssertEqual(vm.run.phase, .finished)
        XCTAssertEqual(audio.alertPlays, 1)
        assertQuiet()
    }

    /// End flight is only offered on ready and time-up (not while counting),
    /// so the leg runs to time-up first.
    func testStartTimeUpThenEndFlightLeavesNothingActive() {
        vm.primaryTapped()
        clock.now = clock.now.addingTimeInterval(60)
        timers.active.first { $0.fire != nil }?.action()
        vm.refresh()
        XCTAssertEqual(audio.playing, .alert)
        vm.endFlightConfirmed()
        XCTAssertEqual(vm.run.phase, .finished)
        XCTAssertEqual(audio.alertPlays, 1)
        assertQuiet()
    }
}
