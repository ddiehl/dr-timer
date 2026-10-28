import SwiftUI
import DRCore

struct FlightsListView: View {
    @Environment(AppModel.self) private var model
    @State private var newFlight: Flight?
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                if let error = model.storageError {
                    Text(error).foregroundStyle(.red)
                }
                if model.flights.isEmpty {
                    Text("No flights yet. Tap + to plan one.").foregroundStyle(.secondary)
                }
                ForEach(model.flights) { flight in
                    NavigationLink {
                        FlightEditorView(flight: flight, isNew: false)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(flight.name).font(.headline)
                            Text("\(flight.legs.count) legs · \(TimeFormat.mmss(flight.totalSeconds))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.deleteFlight(id: flight.id)
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            model.duplicateFlight(id: flight.id)
                        } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Flights")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("About")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newFlight = Flight(name: "", legs: [])
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New flight")
                }
            }
            .sheet(item: $newFlight) { flight in
                NavigationStack { FlightEditorView(flight: flight, isNew: true) }
            }
            .sheet(isPresented: $showingAbout) {
                NavigationStack { AboutView() }
            }
        }
    }
}
