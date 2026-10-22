import SwiftUI

/// Full-screen red/blue alternating background for the time-up screen.
///
/// Normal: hard swap between red and blue every 0.5 s (two colour changes per
/// second, well under the 3-flashes-per-second photosensitivity guideline).
/// Reduce Motion: a slow, smooth fade between the same two colours instead.
struct FlashingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let red = Color(red: 0.85, green: 0.0, blue: 0.0)
    static let blue = Color(red: 0.0, green: 0.15, blue: 0.85)
    /// Seconds each colour is shown when flashing.
    static let flashInterval: TimeInterval = 0.5
    /// Seconds for a full red -> blue -> red fade with Reduce Motion on.
    static let fadePeriod: TimeInterval = 3.0

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 30 : Self.flashInterval / 2)) { context in
            ZStack {
                Self.red
                Self.blue.opacity(Self.blueAmount(at: context.date, reduceMotion: reduceMotion))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// 0 = fully red, 1 = fully blue.
    static func blueAmount(at date: Date, reduceMotion: Bool) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        if reduceMotion {
            return (1 - cos(2 * .pi * t / fadePeriod)) / 2
        }
        return Int(floor(t / flashInterval)) % 2 == 0 ? 0 : 1
    }
}

#Preview {
    FlashingBackground()
}
