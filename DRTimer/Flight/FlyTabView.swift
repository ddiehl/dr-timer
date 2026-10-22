import SwiftUI
import DRCore

/// Fly tab: picker until a run exists, then the run screens. A run saved by a
/// previous launch resumes straight into its phase.
struct FlyTabView: View {
    @Environment(AppModel.self) private var model
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
            viewModel = RunViewModel.restoreIfAny(
                store: model.runStore, clock: SystemClock(), alerts: NoOpAlerts())
        }
    }

    private func start(_ flight: Flight) {
        guard flight.isValid else { return }
        let vm = RunViewModel(run: FlightRun(flight: flight), store: model.runStore,
                              clock: SystemClock(), alerts: NoOpAlerts())
        vm.persistInitial()
        viewModel = vm
    }
}
