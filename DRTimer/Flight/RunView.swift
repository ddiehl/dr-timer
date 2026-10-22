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
            case .ready, .counting, .paused:
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

/// Top-right X that ends the flight, after a confirmation so a stray tap can't.
struct EndFlightControl: View {
    let action: () -> Void
    @State private var confirming = false
    var body: some View {
        Button { confirming = true } label: {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.55), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
        }
        .padding(16)
        .accessibilityLabel("End flight")
        .confirmationDialog("End this flight?", isPresented: $confirming, titleVisibility: .visible) {
            Button("End flight", role: .destructive, action: action)
            Button("Keep flying", role: .cancel) {}
        }
    }
}
