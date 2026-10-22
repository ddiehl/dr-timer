import Foundation
import Observation
import DRCore

protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

protocol AlertControlling {
    /// Must replace any pending time-up request (implementations use a stable identifier).
    func scheduleTimeUp(at: Date, landmark: String)
    func startRinging()
    func stopRinging()
    func cancelScheduled()
}

@Observable
final class RunViewModel {
    private(set) var run: FlightRun
    private(set) var remainingSeconds: Int = 0
    /// Set when the run could not be saved, so the UI can tell the pilot.
    var saveError: String?

    private let store: RunStore
    private let clock: Clock
    private let alerts: AlertControlling
    private var ringingStarted = false

    init(run: FlightRun, store: RunStore, clock: Clock, alerts: AlertControlling) {
        self.run = run
        self.store = store
        self.clock = clock
        self.alerts = alerts
        remainingSeconds = run.remaining(at: clock.now)
    }

    /// Resumes a saved, unfinished run in the correct phase.
    static func restoreIfAny(store: RunStore, clock: Clock, alerts: AlertControlling) -> RunViewModel? {
        guard let saved = store.load() else { return nil }
        if saved.phase == .finished {
            store.clear()
            return nil
        }
        let vm = RunViewModel(run: saved, store: store, clock: clock, alerts: alerts)
        // Only a still-counting leg needs a notification; a past end date goes
        // straight to time-up and rings via refresh().
        if case .counting(_, let endsAt) = saved.phase, endsAt > clock.now, let leg = saved.currentLeg {
            alerts.scheduleTimeUp(at: endsAt, landmark: leg.landmark)
        }
        vm.refresh()
        return vm
    }

    func refresh() {
        let before = run
        run.tick(at: clock.now)
        remainingSeconds = run.remaining(at: clock.now)
        if run != before { save() }
        if case .timeUp = run.phase, !ringingStarted {
            ringingStarted = true
            alerts.startRinging()
        }
    }

    func primaryTapped() {
        switch run.phase {
        case .ready, .timeUp: break
        case .counting, .paused, .finished: return
        }
        run.advance(at: clock.now)
        ringingStarted = false
        alerts.stopRinging()
        remainingSeconds = run.remaining(at: clock.now)
        if case .counting(_, let endsAt) = run.phase, let leg = run.currentLeg {
            alerts.scheduleTimeUp(at: endsAt, landmark: leg.landmark)
        }
        save()
    }

    /// Freezes the countdown and cancels the pending time-up alert.
    func pauseTapped() {
        guard case .counting = run.phase else { return }
        run.pause(at: clock.now)
        alerts.cancelScheduled()
        remainingSeconds = run.remaining(at: clock.now)
        save()
    }

    /// Continues from the frozen time and re-arms the alert.
    func resumeTapped() {
        guard case .paused = run.phase else { return }
        run.resume(at: clock.now)
        remainingSeconds = run.remaining(at: clock.now)
        scheduleCurrentLeg()
        save()
    }

    /// Skips the running or paused countdown and starts the next leg now.
    func nextLegTapped() {
        switch run.phase {
        case .counting, .paused: break
        default: return
        }
        run.skipToNextLeg(at: clock.now)
        ringingStarted = false
        alerts.stopRinging()
        alerts.cancelScheduled()
        remainingSeconds = run.remaining(at: clock.now)
        scheduleCurrentLeg()
        save()
    }

    private func scheduleCurrentLeg() {
        if case .counting(_, let endsAt) = run.phase, let leg = run.currentLeg {
            alerts.scheduleTimeUp(at: endsAt, landmark: leg.landmark)
        }
    }

    func endFlightConfirmed() {
        let before = run
        run.endFlight()
        guard run != before else { return }
        ringingStarted = false
        alerts.stopRinging()
        alerts.cancelScheduled()
        remainingSeconds = 0
        save()
    }

    /// Saves the freshly created run so a relaunch resumes it at the ready screen.
    func persistInitial() { save() }

    private func save() {
        if run.phase == .finished {
            store.clear()
            return
        }
        do {
            try store.save(run)
            saveError = nil
        } catch {
            saveError = "Could not save the flight in progress: \(error.localizedDescription)"
        }
    }
}
