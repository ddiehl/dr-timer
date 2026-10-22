import SwiftUI
import DRCore

struct FlightPickerView: View {
    @Environment(AppModel.self) private var model
    let onStart: (Flight) -> Void

    var body: some View {
        NavigationStack {
            List {
                if model.flights.isEmpty {
                    Text("No flights yet. Plan one in the Plan tab.").foregroundStyle(.secondary)
                }
                ForEach(model.flights) { flight in
                    Button {
                        if flight.isValid { onStart(flight) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.name).font(.title3.bold())
                            if flight.isValid {
                                Text("\(flight.legs.count) legs · \(TimeFormat.mmss(flight.totalSeconds))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Incomplete: fix this flight in the Plan tab")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .disabled(!flight.isValid)
                }
            }
            .navigationTitle("Choose flight")
        }
    }
}
