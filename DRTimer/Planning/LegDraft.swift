import Foundation
import DRCore

/// Text-field state for the leg editor. `leg` is nil unless the draft is valid.
struct LegDraft {
    var landmark: String = ""
    var minutes: String = ""
    var seconds: String = ""
    var id: UUID = UUID()

    init(landmark: String = "", minutes: String = "", seconds: String = "") {
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
            return "Enter minutes and seconds (seconds 0-59) from 00:01 to 99:59."
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
