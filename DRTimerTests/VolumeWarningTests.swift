import XCTest
@testable import DRTimer

final class VolumeWarningTests: XCTestCase {
    func testBelowThresholdShowsOnReadyAndPicker() {
        XCTAssertTrue(VolumeWarning.isVisible(volume: 0.49, screen: .picker))
        XCTAssertTrue(VolumeWarning.isVisible(volume: 0.0, screen: .ready))
    }

    func testAtOrAboveThresholdHidden() {
        XCTAssertFalse(VolumeWarning.isVisible(volume: 0.5, screen: .picker))
        XCTAssertFalse(VolumeWarning.isVisible(volume: 1.0, screen: .ready))
    }

    func testNeverShownWhileCountingTimeUpOrFinished() {
        for screen in [VolumeWarning.Screen.counting, .timeUp, .finished] {
            XCTAssertFalse(VolumeWarning.isVisible(volume: 0.0, screen: screen))
        }
    }

    func testMonitorReportsInjectedVolumeAndUpdates() {
        let source = FakeVolumeSource(0.2)
        let monitor = VolumeMonitor(source: source)
        XCTAssertEqual(monitor.volume, 0.2)
        source.set(0.9)
        XCTAssertEqual(monitor.volume, 0.9)
    }
}

private final class FakeVolumeSource: VolumeReading {
    var outputVolume: Float
    private var handler: ((Float) -> Void)?
    init(_ v: Float) { outputVolume = v }
    func observe(_ onChange: @escaping (Float) -> Void) { handler = onChange }
    func set(_ v: Float) { outputVolume = v; handler?(v) }
}
