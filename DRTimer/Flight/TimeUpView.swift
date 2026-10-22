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
            Color.red.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("LOOK FOR")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(landmark)
                    .font(.system(size: 96, weight: .heavy))
                    .minimumScaleFactor(0.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
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
                EndFlightControl(action: onEnd)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("70-character landmark") {
    TimeUpContent(
        landmark: "Large white barn with a red roof next to the grain elevator by hwy 12",
        buttonTitle: "OVER IT: START LEG 2", onPrimary: {}, onEnd: {})
}
