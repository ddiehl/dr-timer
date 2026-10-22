import Foundation

/// Stores the saved flights as one JSON file. Dates use Foundation's default
/// encoding (Double seconds), which round-trips exactly.
public final class FlightRepository {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadAll() throws -> [Flight] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Flight].self, from: data)
    }

    public func save(_ flights: [Flight]) throws {
        let data = try JSONEncoder().encode(flights)
        try data.write(to: fileURL, options: .atomic)
    }
}
