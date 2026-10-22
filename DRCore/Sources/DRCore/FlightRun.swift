import Foundation

public enum RunPhase: Codable, Equatable, Sendable {
    case ready(leg: Int)
    case counting(leg: Int, endsAt: Date)
    case paused(leg: Int, remaining: TimeInterval)
    case timeUp(leg: Int)
    case finished
}

/// Pure state machine for a flight in progress. Never reads the system clock;
/// all times are supplied by the caller as `now`.
public struct FlightRun: Codable, Equatable, Sendable {
    public let flight: Flight
    public private(set) var phase: RunPhase

    public init(flight: Flight) {
        self.flight = flight
        self.phase = .ready(leg: 0)
    }

    public var currentLegIndex: Int? {
        switch phase {
        case .ready(let n), .counting(let n, _), .paused(let n, _), .timeUp(let n): return n
        case .finished: return nil
        }
    }

    public var currentLeg: Leg? {
        guard let i = currentLegIndex, flight.legs.indices.contains(i) else { return nil }
        return flight.legs[i]
    }

    public var isLastLeg: Bool {
        guard let i = currentLegIndex else { return false }
        return i == flight.legs.count - 1
    }

    /// Whole seconds left, rounded up, never negative. While paused it is the
    /// frozen time left; 0 in any other non-counting phase (ready, timeUp, finished).
    public func remaining(at now: Date) -> Int {
        switch phase {
        case .counting(_, let endsAt): return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        case .paused(_, let left): return max(0, Int(ceil(left)))
        default: return 0
        }
    }

    public mutating func tick(at now: Date) {
        if case .counting(let n, let endsAt) = phase, now >= endsAt {
            phase = .timeUp(leg: n)
        }
    }

    public mutating func advance(at now: Date) {
        switch phase {
        case .ready(let n):
            guard flight.legs.indices.contains(n) else { phase = .finished; return }
            phase = .counting(leg: n, endsAt: now.addingTimeInterval(TimeInterval(flight.legs[n].seconds)))
        case .timeUp(let n):
            let next = n + 1
            if flight.legs.indices.contains(next) {
                phase = .counting(leg: next, endsAt: now.addingTimeInterval(TimeInterval(flight.legs[next].seconds)))
            } else {
                phase = .finished
            }
        case .counting, .paused, .finished:
            break
        }
    }

    /// Freezes the countdown. Only valid while counting.
    public mutating func pause(at now: Date) {
        if case .counting(let n, let endsAt) = phase, now < endsAt {
            phase = .paused(leg: n, remaining: endsAt.timeIntervalSince(now))
        }
    }

    /// Continues a paused countdown with the frozen time left.
    public mutating func resume(at now: Date) {
        if case .paused(let n, let left) = phase {
            phase = .counting(leg: n, endsAt: now.addingTimeInterval(left))
        }
    }

    /// Abandons the current countdown (counting or paused) and starts the next
    /// leg now, as if the pilot had reached the landmark early. After the last
    /// leg the flight finishes.
    public mutating func skipToNextLeg(at now: Date) {
        switch phase {
        case .counting(let n, _), .paused(let n, _):
            phase = .timeUp(leg: n)
            advance(at: now)
        case .ready, .timeUp, .finished:
            break
        }
    }

    public mutating func endFlight() {
        switch phase {
        case .ready, .timeUp: phase = .finished
        case .counting, .paused, .finished: break
        }
    }
}
