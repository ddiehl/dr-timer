import SwiftUI

@main
struct DRTimerApp: App {
    @State private var model = AppModel.production()
    /// One alert manager for the app's lifetime: it owns the audio session,
    /// the pending notification and the ringing state.
    @State private var alerts = AlertManager.production()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                FlyTabView(alerts: alerts)
                    .tabItem { Label("Fly", systemImage: "timer") }
                FlightsListView()
                    .tabItem { Label("Plan", systemImage: "list.bullet") }
            }
            .environment(model)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Keep the screen awake while the app is on screen. `.inactive` (Control
            // Center or Notification Center pulled down, an incoming-call banner)
            // still counts: the screen must not lock mid-leg. Only release it
            // once the app is really in the background.
            UIApplication.shared.isIdleTimerDisabled = (phase != .background)
        }
    }
}
