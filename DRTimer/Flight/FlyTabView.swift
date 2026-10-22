import SwiftUI
import DRCore

/// Fly tab: picker until a run exists, then the run screens. A run saved by a
/// previous launch resumes straight into its phase.
struct FlyTabView: View {
    @Environment(AppModel.self) private var model
    let alerts: AlertManager
    @State private var viewModel: RunViewModel?
    @State private var restored = false

    var body: some View {
        Group {
            if let viewModel {
                RunView(viewModel: viewModel, onExit: { self.viewModel = nil })
                    .toolbar(.hidden, for: .tabBar)
            } else {
                FlightPickerView { flight in start(flight) }
            }
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            // First appearance of the Fly tab: ask for notification permission
            // (iOS only shows the prompt once; later calls are no-ops).
            alerts.requestNotificationPermission()
            viewModel = RunViewModel.restoreIfAny(
                store: model.runStore, clock: SystemClock(), alerts: alerts)
        }
    }

    private func start(_ flight: Flight) {
        guard flight.isValid else { return }
        let vm = RunViewModel(run: FlightRun(flight: flight), store: model.runStore,
                              clock: SystemClock(), alerts: alerts)
        vm.persistInitial()
        viewModel = vm
    }
}
