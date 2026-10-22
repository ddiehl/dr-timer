import Foundation

public struct Leg: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var landmark: String
    public var seconds: Int

    public static let secondsRange: ClosedRange<Int> = 1...5999

    public init(id: UUID = UUID(), landmark: String, seconds: Int) {
        self.id = id
        self.landmark = landmark
        self.seconds = seconds
    }

    public var isValid: Bool {
        !landmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Leg.secondsRange.contains(seconds)
    }
}

public enum TimeFormat {
    public static func mmss(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public static func parse(minutes: String, seconds: String) -> Int? {
        func isDigits(_ s: String) -> Bool {
            !s.isEmpty && s.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
        }
        guard isDigits(minutes), isDigits(seconds),
              let m = Int(minutes), let s = Int(seconds),
              (0...59).contains(s) else { return nil }
        let total = m * 60 + s
        return Leg.secondsRange.contains(total) ? total : nil
    }
}
