import Foundation

public struct Flight: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var legs: [Leg]

    public init(id: UUID = UUID(), name: String, legs: [Leg]) {
        self.id = id
        self.name = name
        self.legs = legs
    }

    public var totalSeconds: Int { legs.reduce(0) { $0 + $1.seconds } }

    public var isValid: Bool { !legs.isEmpty && legs.allSatisfy(\.isValid) }
}
