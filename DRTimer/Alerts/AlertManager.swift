import Foundation

// MARK: - Seams
// The alert logic talks only to these small protocols so it can be unit-tested
// with fakes. The real iOS adapters live in AlertAdapters.swift.

/// Which looping sound the audio layer should play.
enum AlertSound {
    /// The audible time-up alarm (alert.wav).
    case alert
    /// A silent loop played while a leg counts down. Its only job is to keep the
    /// app running in the background (UIBackgroundModes: audio) so it can start
    /// the real alert at the exact end time even when the phone is locked.
    case keepAlive
}

protocol AudioPlaying: AnyObject {
    /// Plays `sound` on an endless loop, replacing whatever was playing.
    func playLoop(_ sound: AlertSound)
    func stop()
}

protocol Haptics {
    func pulse()
}

/// A local notification request, kept as plain data so tests can inspect it.
struct PendingNotification: Equatable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
    /// File name of a bundled sound (under 30 s).
    let soundName: String
}

protocol NotificationScheduling {
    func add(_ notification: PendingNotification)
    /// Removes both the pending and any already-delivered notification with this id.
    func remove(id: String)
    func requestAuthorization()
}

protocol AlertTimer: AnyObject {
    func cancel()
}

protocol TimerScheduling {
    func schedule(at date: Date, _ action: @escaping () -> Void) -> AlertTimer
    func repeating(every interval: TimeInterval, _ action: @escaping () -> Void) -> AlertTimer
}

// MARK: - AlertManager

/// Drives everything the pilot hears, feels and gets notified about at time-up.
///
/// Mechanism (see docs/device-test-checklist.md for limits):
/// - While a leg counts down, a silent audio loop keeps the app alive in the
///   background, and an in-app timer starts the real alert at the end date.
/// - A local notification at the same date is the safety net for when the app
///   is not running at all (force-quit, or iOS killed it).
///
/// Call from the main thread only.
final class AlertManager: AlertControlling {
    /// Stable id, so a new schedule always replaces the previous request.
    static let timeUpNotificationID = "drtimer.time-up"
    static let notificationSoundName = "alert.wav"
    static let hapticInterval: TimeInterval = 1.0

    private(set) var isRinging = false

    private let audio: AudioPlaying
    private let haptics: Haptics
    private let notifications: NotificationScheduling
    private let timers: TimerScheduling
    private var endTimer: AlertTimer?
    private var hapticTimer: AlertTimer?

    init(audio: AudioPlaying, haptics: Haptics, notifications: NotificationScheduling, timers: TimerScheduling) {
        self.audio = audio
        self.haptics = haptics
        self.notifications = notifications
        self.timers = timers
    }

    func requestNotificationPermission() {
        notifications.requestAuthorization()
    }

    func scheduleTimeUp(at date: Date, landmark: String) {
        notifications.remove(id: Self.timeUpNotificationID)
        notifications.add(PendingNotification(
            id: Self.timeUpNotificationID,
            fireDate: date,
            title: "TIME'S UP",
            body: "Look for: \(landmark)",
            soundName: Self.notificationSoundName))

        endTimer?.cancel()
        endTimer = timers.schedule(at: date) { [weak self] in self?.startRinging() }

        if !isRinging { audio.playLoop(.keepAlive) }
    }

    func startRinging() {
        guard !isRinging else { return }
        isRinging = true
        endTimer?.cancel()
        endTimer = nil
        audio.playLoop(.alert)
        haptics.pulse()
        hapticTimer = timers.repeating(every: Self.hapticInterval) { [weak self] in
            self?.haptics.pulse()
        }
    }

    func stopRinging() {
        guard isRinging else { return }
        isRinging = false
        hapticTimer?.cancel()
        hapticTimer = nil
        audio.stop()
        // The pilot has acknowledged time-up: clear the banner if it is showing.
        notifications.remove(id: Self.timeUpNotificationID)
    }

    func cancelScheduled() {
        notifications.remove(id: Self.timeUpNotificationID)
        endTimer?.cancel()
        endTimer = nil
        if !isRinging { audio.stop() }
    }
}
