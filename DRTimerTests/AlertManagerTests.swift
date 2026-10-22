import XCTest
@testable import DRTimer

// MARK: - Fakes

private final class FakeAudio: AudioPlaying {
    var calls: [String] = []
    var playing: AlertSound?
    func playLoop(_ sound: AlertSound) { calls.append("play:\(sound)"); playing = sound }
    func stop() { calls.append("stop"); playing = nil }
    /// Simulates a player that silently failed or was paused by the system.
    var failedSilently = false
    var ensureCalls = 0
    var restarts = 0
    func ensurePlaying() {
        ensureCalls += 1
        if failedSilently, playing != nil { restarts += 1; failedSilently = false }
    }
}

private final class FakeHaptics: Haptics {
    var pulses = 0
    func pulse() { pulses += 1 }
}

private final class FakeNotifications: NotificationScheduling {
    var calls: [String] = []
    var pending: [String: PendingNotification] = [:]
    var authorizationRequests = 0
    func add(_ n: PendingNotification) { calls.append("add:\(n.id)"); pending[n.id] = n }
    func remove(id: String) { calls.append("remove:\(id)"); pending[id] = nil }
    func requestAuthorization() { authorizationRequests += 1 }
}

private final class FakeTimer: AlertTimer {
    let fireDate: Date?
    let interval: TimeInterval?
    let action: () -> Void
    var cancelled = false
    init(fireDate: Date?, interval: TimeInterval?, action: @escaping () -> Void) {
        self.fireDate = fireDate; self.interval = interval; self.action = action
    }
    func cancel() { cancelled = true }
    func fire() { if !cancelled { action() } }
}

private final class FakeTimers: TimerScheduling {
    var oneShots: [FakeTimer] = []
    var repeating: [FakeTimer] = []
    func schedule(at date: Date, _ action: @escaping () -> Void) -> AlertTimer {
        let t = FakeTimer(fireDate: date, interval: nil, action: action); oneShots.append(t); return t
    }
    func repeating(every interval: TimeInterval, _ action: @escaping () -> Void) -> AlertTimer {
        let t = FakeTimer(fireDate: nil, interval: interval, action: action); repeating.append(t); return t
    }
    var activeOneShots: [FakeTimer] { oneShots.filter { !$0.cancelled } }
    var activeRepeating: [FakeTimer] { repeating.filter { !$0.cancelled } }
}

// MARK: - Tests

final class AlertManagerTests: XCTestCase {
    private var audio: FakeAudio!
    private var haptics: FakeHaptics!
    private var notifications: FakeNotifications!
    private var timers: FakeTimers!
    private var manager: AlertManager!
    private let end = Date(timeIntervalSince1970: 2_000_000)

    override func setUp() {
        audio = FakeAudio()
        haptics = FakeHaptics()
        notifications = FakeNotifications()
        timers = FakeTimers()
        manager = AlertManager(audio: audio, haptics: haptics, notifications: notifications, timers: timers)
    }

    func testScheduleAddsNotificationAtEndDate() {
        manager.scheduleTimeUp(at: end, landmark: "Water tower")
        let n = notifications.pending[AlertManager.timeUpNotificationID]
        XCTAssertEqual(n?.fireDate, end)
        XCTAssertTrue(n?.body.contains("Water tower") ?? false)
        XCTAssertEqual(n?.soundName, AlertManager.notificationSoundName)
        XCTAssertEqual(notifications.pending.count, 1)
    }

    func testScheduleTwiceReplacesPendingRequest() {
        manager.scheduleTimeUp(at: end, landmark: "A")
        manager.scheduleTimeUp(at: end.addingTimeInterval(30), landmark: "B")
        XCTAssertEqual(notifications.pending.count, 1)
        XCTAssertEqual(notifications.pending[AlertManager.timeUpNotificationID]?.fireDate, end.addingTimeInterval(30))
        // Remove before every add, using the same stable id.
        let id = AlertManager.timeUpNotificationID
        XCTAssertEqual(notifications.calls, ["remove:\(id)", "add:\(id)", "remove:\(id)", "add:\(id)"])
        XCTAssertEqual(timers.activeOneShots.count, 1)
        XCTAssertEqual(timers.activeOneShots.first?.fireDate, end.addingTimeInterval(30))
    }

    func testScheduleKeepsAudioAliveAndRingsAtEndDate() {
        manager.scheduleTimeUp(at: end, landmark: "A")
        XCTAssertEqual(audio.playing, .keepAlive)
        XCTAssertEqual(timers.activeOneShots.first?.fireDate, end)
        timers.activeOneShots.first?.fire()
        XCTAssertEqual(audio.playing, .alert)
        XCTAssertTrue(manager.isRinging)
    }

    func testStartRingingStartsAudioLoopAndHaptics() {
        manager.startRinging()
        XCTAssertEqual(audio.playing, .alert)
        XCTAssertEqual(haptics.pulses, 1, "first pulse is immediate")
        XCTAssertEqual(timers.activeRepeating.count, 1)
        XCTAssertEqual(timers.activeRepeating.first?.interval ?? 0, 1.0, accuracy: 0.01)
        timers.activeRepeating.first?.fire()
        timers.activeRepeating.first?.fire()
        XCTAssertEqual(haptics.pulses, 3)
    }

    func testEveryHapticTickChecksAudioIsStillPlaying() {
        manager.startRinging()
        XCTAssertEqual(audio.ensureCalls, 0)
        timers.activeRepeating.first?.fire()
        XCTAssertEqual(audio.ensureCalls, 1)
        timers.activeRepeating.first?.fire()
        XCTAssertEqual(audio.ensureCalls, 2)
    }

    func testWatchdogRestartsAlertThatFailedToPlay() {
        manager.startRinging()
        audio.failedSilently = true // e.g. AVAudioPlayer.play() returned false
        timers.activeRepeating.first?.fire()
        XCTAssertEqual(audio.restarts, 1, "next pulse restarts the loop")
        XCTAssertEqual(audio.playing, .alert)
    }

    func testNoWatchdogAfterStop() {
        manager.startRinging()
        manager.stopRinging()
        timers.repeating.first?.fire()
        XCTAssertEqual(audio.ensureCalls, 0)
    }

    func testStopRingingStopsBoth() {
        manager.startRinging()
        manager.stopRinging()
        XCTAssertNil(audio.playing)
        XCTAssertFalse(manager.isRinging)
        XCTAssertTrue(timers.activeRepeating.isEmpty)
        timers.repeating.first?.fire()
        XCTAssertEqual(haptics.pulses, 1, "no pulses after stop")
    }

    func testCancelScheduledRemovesRequest() {
        manager.scheduleTimeUp(at: end, landmark: "A")
        manager.cancelScheduled()
        XCTAssertTrue(notifications.pending.isEmpty)
        XCTAssertTrue(timers.activeOneShots.isEmpty)
        XCTAssertNil(audio.playing, "keep-alive audio stops when nothing is scheduled")
    }

    func testStartRingingTwiceDoesNotDoubleStart() {
        manager.startRinging()
        manager.startRinging()
        XCTAssertEqual(audio.calls.filter { $0.hasPrefix("play:alert") }.count, 1)
        XCTAssertEqual(timers.activeRepeating.count, 1)
        XCTAssertEqual(haptics.pulses, 1)
    }

    func testEndTimerFiringThenForegroundStartRingingRingsOnce() {
        manager.scheduleTimeUp(at: end, landmark: "A")
        timers.activeOneShots.first?.fire()
        manager.startRinging() // RunViewModel.refresh() on return to foreground
        XCTAssertEqual(audio.calls.filter { $0.hasPrefix("play:alert") }.count, 1)
    }

    func testRingingClearsPendingNotificationOnStop() {
        manager.scheduleTimeUp(at: end, landmark: "A")
        timers.activeOneShots.first?.fire()
        manager.stopRinging()
        XCTAssertTrue(notifications.pending.isEmpty)
    }

    func testRequestPermissionForwards() {
        manager.requestNotificationPermission()
        XCTAssertEqual(notifications.authorizationRequests, 1)
    }
}
