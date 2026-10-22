import Foundation
import DRCore

/// Text-field state for the leg editor. `leg` is nil unless the draft is valid.
struct LegDraft {
    var landmark: String = ""
    var minutes: String = "0"
    var seconds: String = "0"
    var id: UUID = UUID()

    init(landmark: String = "", minutes: String = "0", seconds: String = "0") {
        self.landmark = landmark
        self.minutes = minutes
        self.seconds = seconds
    }

    init(leg: Leg) {
        self.id = leg.id
        self.landmark = leg.landmark
        self.minutes = String(leg.seconds / 60)
        self.seconds = String(leg.seconds % 60)
    }

    var errorMessage: String? {
        if landmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a landmark name."
        }
        if TimeFormat.parse(minutes: minutes, seconds: seconds) == nil {
            return "Set a leg time greater than 00:00."
        }
        return nil
    }

    var leg: Leg? {
        guard errorMessage == nil,
              let total = TimeFormat.parse(minutes: minutes, seconds: seconds) else { return nil }
        return Leg(id: id,
                   landmark: landmark.trimmingCharacters(in: .whitespacesAndNewlines),
                   seconds: total)
    }
}
