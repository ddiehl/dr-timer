import SwiftUI
import DRCore

struct RunView: View {
    let viewModel: RunViewModel
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch viewModel.run.phase {
            case .ready, .counting:
                ReadyOrCountingView(viewModel: viewModel)
            case .timeUp:
                TimeUpView(viewModel: viewModel)
            case .finished:
                FinishedView(onDone: onExit)
            }
        }
        .onReceive(timer) { _ in viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
        .onAppear { viewModel.refresh() }
    }
}

struct FinishedView: View {
    let onDone: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text("FLIGHT COMPLETE")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                Button(action: onDone) {
                    Text("DONE")
                        .font(.system(size: 32, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            }
        }
    }
}

/// Small, deliberate control: must be pressed and held to end the flight.
struct EndFlightControl: View {
    let action: () -> Void
    var body: some View {
        Text("End flight (hold)")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
            .padding(10)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1.0, perform: action)
            .accessibilityLabel("End flight")
            .accessibilityHint("Press and hold to end the flight")
    }
}
