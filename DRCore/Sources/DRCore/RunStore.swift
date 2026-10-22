import Foundation

/// Persists the in-progress run so it survives relaunch. A missing or corrupt
/// file loads as nil. Dates use Foundation's default encoding (Double seconds),
/// which round-trips the countdown end date exactly.
public final class RunStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> FlightRun? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(FlightRun.self, from: data)
    }

    public func save(_ run: FlightRun) throws {
        let data = try JSONEncoder().encode(run)
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
