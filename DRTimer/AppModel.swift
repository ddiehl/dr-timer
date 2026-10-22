import Foundation
import Observation
import DRCore

@Observable
final class AppModel {
    private(set) var flights: [Flight] = []
    /// Set when loading or saving fails, so the UI can tell the pilot.
    var storageError: String?

    let repository: FlightRepository
    let runStore: RunStore

    init(repository: FlightRepository, runStore: RunStore) {
        self.repository = repository
        self.runStore = runStore
        do {
            flights = try repository.loadAll()
        } catch {
            storageError = Self.moveUnreadableFileAside(repository.fileURL, reason: error)
        }
    }

    /// An unreadable flights file must never be overwritten by the next save:
    /// rename it to flights.corrupt-<timestamp>.json beside the original.
    private static func moveUnreadableFileAside(_ url: URL, reason: Error) -> String {
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).corrupt-\(stamp).\(url.pathExtension)")
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            return "Could not load saved flights (\(reason.localizedDescription)). The old data was kept at \(aside.lastPathComponent)."
        } catch {
            return "Could not load saved flights (\(reason.localizedDescription)) and could not set the file aside: \(error.localizedDescription)"
        }
    }

    /// Production wiring: files live in the app's Documents directory.
    static func production() -> AppModel {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return AppModel(
            repository: FlightRepository(fileURL: dir.appendingPathComponent("flights.json")),
            runStore: RunStore(fileURL: dir.appendingPathComponent("run.json")))
    }

    func addFlight(_ flight: Flight) {
        flights.append(flight)
        persist()
    }

    func updateFlight(_ flight: Flight) {
        guard let i = flights.firstIndex(where: { $0.id == flight.id }) else { return }
        flights[i] = flight
        persist()
    }

    func deleteFlight(id: UUID) {
        flights.removeAll { $0.id == id }
        persist()
    }

    func duplicateFlight(id: UUID) {
        guard let i = flights.firstIndex(where: { $0.id == id }) else { return }
        let original = flights[i]
        let copy = Flight(
            name: original.name + " copy",
            legs: original.legs.map { Leg(landmark: $0.landmark, seconds: $0.seconds) })
        flights.insert(copy, at: i + 1)
        persist()
    }

    private func persist() {
        do {
            try repository.save(flights)
            storageError = nil
        } catch {
            storageError = "Could not save flights: \(error.localizedDescription)"
        }
    }
}
