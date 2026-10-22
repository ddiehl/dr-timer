import AVFoundation
import Observation

/// Where the media volume comes from; a seam so the warning logic is testable.
protocol VolumeReading: AnyObject {
    var outputVolume: Float { get }
    /// Calls `onChange` (on the main thread) whenever the volume changes.
    func observe(_ onChange: @escaping (Float) -> Void)
}

/// Pure rule for the "volume low" warning.
enum VolumeWarning {
    enum Screen { case picker, ready, counting, timeUp, finished }
    static let threshold: Float = 0.5

    static func isVisible(volume: Float, screen: Screen) -> Bool {
        guard screen == .picker || screen == .ready else { return false }
        return volume < threshold
    }
}

/// Live media volume for the UI.
@Observable
final class VolumeMonitor {
    private(set) var volume: Float
    private let source: VolumeReading

    init(source: VolumeReading) {
        self.source = source
        volume = source.outputVolume
        source.observe { [weak self] v in self?.volume = v }
    }

    static func production() -> VolumeMonitor { VolumeMonitor(source: SessionVolumeSource()) }

    func isWarningVisible(on screen: VolumeWarning.Screen) -> Bool {
        VolumeWarning.isVisible(volume: volume, screen: screen)
    }
}

/// Reads `AVAudioSession.outputVolume` with KVO. The shared session is
/// activated in the same `.playback` + `.mixWithOthers` configuration the alert
/// uses, so the reading is accurate before any leg has started (outputVolume is
/// only reliable on an active session) without interrupting other audio.
final class SessionVolumeSource: VolumeReading {
    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?

    init() {
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
        try? session.setActive(true)
    }

    var outputVolume: Float { session.outputVolume }

    func observe(_ onChange: @escaping (Float) -> Void) {
        observation = session.observe(\.outputVolume, options: [.new]) { _, change in
            guard let v = change.newValue else { return }
            DispatchQueue.main.async { onChange(v) }
        }
    }
}
