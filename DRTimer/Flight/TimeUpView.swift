import SwiftUI
import DRCore

struct TimeUpView: View {
    let viewModel: RunViewModel

    private var buttonTitle: String {
        if viewModel.run.isLastLeg { return "FINISH" }
        return "OVER IT: START LEG \((viewModel.run.currentLegIndex ?? 0) + 2)"
    }

    var body: some View {
        TimeUpContent(
            landmark: viewModel.run.currentLeg?.landmark ?? "",
            buttonTitle: buttonTitle,
            onPrimary: viewModel.primaryTapped,
            onEnd: viewModel.endFlightConfirmed)
    }
}

struct TimeUpContent: View {
    let landmark: String
    let buttonTitle: String
    let onPrimary: () -> Void
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            FlashingBackground()
            VStack(spacing: 16) {
                Text("LOOK FOR")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .modifier(LegibleOnFlash())
                Spacer()
                Text(landmark)
                    .font(.system(size: 96, weight: .heavy))
                    .minimumScaleFactor(0.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .modifier(LegibleOnFlash())
                    .padding(12)
                    // A dark panel keeps contrast steady while the colours swap.
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Button(action: onPrimary) {
                    Text(buttonTitle)
                        .font(.system(size: 32, weight: .heavy))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.red)
            }
            .padding(24)
        }
        .overlay(alignment: .topTrailing) { EndFlightControl(action: onEnd) }
        .preferredColorScheme(.dark)
    }
}

/// White text with a tight dark outline-like shadow, readable on red and on blue.
private struct LegibleOnFlash: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .shadow(color: .black, radius: 0, x: -1, y: -1)
            .shadow(color: .black.opacity(0.8), radius: 4)
    }
}

#Preview("70-character landmark") {
    TimeUpContent(
        landmark: "Large white barn with a red roof next to the grain elevator by hwy 12",
        buttonTitle: "OVER IT: START LEG 2", onPrimary: {}, onEnd: {})
}
