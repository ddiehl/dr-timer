import Foundation

// Compiled together with the DRCore sources, so Codable synthesis is identical
// to the app's. Usage: seed <out-dir> <secondsUntilTimeUp | none>

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args[1])

let monterey = Flight(name: "KSQL → KMRY Coastal", legs: [
    Leg(landmark: "Crystal Springs Res.", seconds: 320),
    Leg(landmark: "Half Moon Bay", seconds: 465),
    Leg(landmark: "Pigeon Point Light", seconds: 550),
    Leg(landmark: "Santa Cruz Pier", seconds: 510),
    Leg(landmark: "Moss Landing Stacks", seconds: 360),
])

let sacramento = Flight(name: "KPAO → KSAC Dual X-C", legs: [
    Leg(landmark: "Dumbarton Bridge", seconds: 270),
    Leg(landmark: "Sunol Ridge", seconds: 375),
    Leg(landmark: "Livermore VOR", seconds: 340),
    Leg(landmark: "Rio Vista Bridge", seconds: 680),
    Leg(landmark: "Sacramento River", seconds: 425),
])

let checkride = Flight(name: "Checkride Practice", legs: [
    Leg(landmark: "Woodside VOR", seconds: 225),
    Leg(landmark: "Crystal Springs", seconds: 250),
    Leg(landmark: "San Mateo Bridge", seconds: 330),
])

let flights = [monterey, sacramento, checkride]
let encoder = JSONEncoder()
try encoder.encode(flights).write(to: outDir.appendingPathComponent("flights.json"))

// A run restored mid-flight: leg 3 of 5, counting down. `advance` twice puts the
// run on leg 2 the way the pilot would have, then the end date is set directly.
if args.count > 2, args[2] != "none", let until = TimeInterval(args[2]) {
    var run = FlightRun(flight: monterey)
    let past = Date(timeIntervalSinceNow: -4000)
    run.advance(at: past)        // leg 0 counting
    run.skipToNextLeg(at: past)  // leg 1 counting
    run.skipToNextLeg(at: Date(timeIntervalSinceNow: until - 550))  // leg 2, ends at `until`
    try encoder.encode(run).write(to: outDir.appendingPathComponent("run.json"))
    print("seeded run: phase=\(run.phase)")
} else {
    try? FileManager.default.removeItem(at: outDir.appendingPathComponent("run.json"))
    print("seeded flights only")
}
print("wrote \(flights.count) flights to \(outDir.path)")
