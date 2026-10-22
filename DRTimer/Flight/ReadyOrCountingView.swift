import SwiftUI
import DRCore

struct ReadyOrCountingView: View {
    let viewModel: RunViewModel
    @Environment(VolumeMonitor.self) private var volume

    private var isReady: Bool {
        if case .ready = viewModel.run.phase { return true }
        return false
    }

    var body: some View {
        let run = viewModel.run
        let legNumber = (run.currentLegIndex ?? 0) + 1
        let seconds = isReady ? (run.currentLeg?.seconds ?? 0) : viewModel.remainingSeconds
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("LEG \(legNumber) OF \(run.flight.legs.count)")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(TimeFormat.mmss(seconds))
                    .font(.system(size: 160, weight: .heavy, design: .monospaced))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text("NEXT: \(run.currentLeg?.landmark ?? "")")
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.yellow)
                Spacer()
                if isReady {
                    if volume.isWarningVisible(on: .ready) { VolumeWarningBanner() }
                    Button(action: viewModel.primaryTapped) {
                        Text("START")
                            .font(.system(size: 44, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .foregroundStyle(.black)
                    EndFlightControl(action: viewModel.endFlightConfirmed)
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}
