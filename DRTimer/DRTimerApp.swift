import SwiftUI

@main
struct DRTimerApp: App {
    @State private var model = AppModel.production()

    var body: some Scene {
        WindowGroup {
            TabView {
                FlyTabView()
                    .tabItem { Label("Fly", systemImage: "timer") }
                FlightsListView()
                    .tabItem { Label("Plan", systemImage: "list.bullet") }
            }
            .environment(model)
        }
    }
}
