import SwiftUI

/// Large, high-contrast warning. Display only: no button, never blocks START.
struct VolumeWarningBanner: View {
    var body: some View {
        Text("VOLUME LOW \u{2013} TURN IT UP")
            .font(.system(size: 28, weight: .heavy))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.yellow)
            .accessibilityAddTraits(.isStaticText)
    }
}
