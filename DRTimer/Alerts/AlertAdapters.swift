import AVFoundation
import AudioToolbox
import Foundation
import UIKit
import UserNotifications
import os

private let log = Logger(subsystem: "com.example.drtimer", category: "alerts")

extension AlertManager {
    /// Production wiring with the real iOS adapters.
    static func production() -> AlertManager {
        AlertManager(audio: SessionAudioPlayer(), haptics: DeviceHaptics(),
                     notifications: UserNotificationScheduler(), timers: RunLoopTimers())
    }
}

// MARK: - Audio

/// Plays the looping sounds through an `AVAudioSession` in the `.playback`
/// category, which ignores the silent switch, keeps playing in the background
/// (with UIBackgroundModes: audio) and follows the current route, so a connected
/// Bluetooth headset gets the sound and the speaker is used otherwise.
final class SessionAudioPlayer: AudioPlaying {
    private let session = AVAudioSession.sharedInstance()
    private var player: AVAudioPlayer?
    private var current: AlertSound?
    private var sessionActive = false

    init() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: session)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: session)
        nc.addObserver(self, selector: #selector(handleMediaServicesReset(_:)),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }

    func playLoop(_ sound: AlertSound) {
        if current == sound, player?.isPlaying == true { return }
        current = sound
        activateSession(force: false)
        // Start the new loop before stopping the old one, so there is never a
        // moment with no audio playing (iOS could suspend a background app then).
        let old = player
        player = makePlayer(for: sound)
        old?.stop()
    }

    func ensurePlaying() {
        resumeIfNeeded()
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
        sessionActive = false
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Audio session deactivate failed: \(error.localizedDescription)")
        }
    }

    /// One fixed configuration for both sounds, so switching from the silent
    /// keep-alive to the alert never touches the session at the critical moment.
    /// `.mixWithOthers`: the keep-alive must not stop the pilot's other audio
    /// (e.g. ForeFlight), and the alert simply plays on top of it.
    private func activateSession(force: Bool) {
        guard force || !sessionActive else { return }
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
            try session.setActive(true)
            sessionActive = true
        } catch {
            sessionActive = false
            log.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    /// Returns the player even if play() failed, so the watchdog can retry it.
    private func makePlayer(for sound: AlertSound) -> AVAudioPlayer? {
        let name = sound == .alert ? "alert" : "silence"
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            log.fault("Missing bundled sound \(name).wav")
            return nil
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1 // until stop()
            p.volume = 1.0
            p.prepareToPlay()
            if !p.play() { log.error("AVAudioPlayer refused to play \(name).wav") }
            return p
        } catch {
            log.error("AVAudioPlayer failed for \(name).wav: \(error.localizedDescription)")
            return nil
        }
    }

    /// Make sure the loop is still going after anything that may have paused it
    /// or stopped it from starting. Called by the ~1 s watchdog while ringing and
    /// on interruption end, route change and media-services reset.
    private func resumeIfNeeded() {
        guard let sound = current else { return }
        if player?.isPlaying == true { return }
        activateSession(force: true)
        if let p = player, p.play() { return }
        let old = player
        player = makePlayer(for: sound)
        old?.stop()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        // On .began the system has already paused us. On .ended we resume
        // regardless of the shouldResume hint: an alarm must keep going.
        if type == .ended {
            DispatchQueue.main.async { self.resumeIfNeeded() }
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // e.g. the headset disconnects: keep ringing on the speaker.
        DispatchQueue.main.async { self.resumeIfNeeded() }
    }

    @objc private func handleMediaServicesReset(_ note: Notification) {
        DispatchQueue.main.async {
            self.player = nil
            self.sessionActive = false
            self.resumeIfNeeded()
        }
    }
}

// MARK: - Haptics

final class DeviceHaptics: Haptics {
    private let generator = UINotificationFeedbackGenerator()

    func pulse() {
        // The system vibration is the strong, long buzz and is not muted by the
        // silent switch; the feedback generator adds a crisp tap in the foreground.
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        generator.notificationOccurred(.warning)
        generator.prepare()
    }
}

// MARK: - Notifications

final class UserNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { log.error("Notification permission error: \(error.localizedDescription)") }
            log.info("Notification permission granted: \(granted)")
        }
    }

    func add(_ n: PendingNotification) {
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(n.soundName))
        // A time-interval trigger is relative and sub-second, unlike a calendar trigger.
        let interval = max(0.5, n.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: n.id, content: content, trigger: trigger)) { error in
            if let error { log.error("Could not schedule notification: \(error.localizedDescription)") }
        }
    }

    func remove(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// In the foreground the time-up screen and the in-app alert take over, so the
    /// notification is not shown or sounded on top of them.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

// MARK: - Timers

/// Main-run-loop timers in `.common` mode. They fire in the background only
/// while the app is still running (kept alive by the keep-alive audio loop).
final class RunLoopTimers: TimerScheduling {
    private final class Handle: AlertTimer {
        let timer: Timer
        init(_ timer: Timer) { self.timer = timer }
        func cancel() { timer.invalidate() }
    }

    func schedule(at date: Date, _ action: @escaping () -> Void) -> AlertTimer {
        let t = Timer(fire: date, interval: 0, repeats: false) { _ in action() }
        t.tolerance = 0
        RunLoop.main.add(t, forMode: .common)
        return Handle(t)
    }

    func repeating(every interval: TimeInterval, _ action: @escaping () -> Void) -> AlertTimer {
        let t = Timer(timeInterval: interval, repeats: true) { _ in action() }
        RunLoop.main.add(t, forMode: .common)
        return Handle(t)
    }
}
