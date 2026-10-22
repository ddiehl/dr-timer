import SwiftUI
import DRCore

struct FlightEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var flight: Flight
    @State private var legDraft: LegDraft?
    private let isNew: Bool

    init(flight: Flight, isNew: Bool) {
        _flight = State(initialValue: flight)
        self.isNew = isNew
    }

    private var blockingReason: String? {
        if flight.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give the flight a name."
        }
        if flight.legs.isEmpty { return "Add at least one leg before saving." }
        return nil
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Flight name", text: $flight.name)
            }
            Section {
                ForEach(flight.legs) { leg in
                    Button {
                        legDraft = LegDraft(leg: leg)
                    } label: {
                        HStack {
                            Text(leg.landmark)
                            Spacer()
                            Text(TimeFormat.mmss(leg.seconds)).monospacedDigit()
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { flight.legs.remove(atOffsets: $0) }
                .onMove { flight.legs.move(fromOffsets: $0, toOffset: $1) }
                Button("+ Add leg") { legDraft = LegDraft() }
            } header: {
                Text("Legs")
            } footer: {
                Text("Total: \(TimeFormat.mmss(flight.totalSeconds))").font(.headline)
            }
            if let reason = blockingReason {
                Section { Text(reason).foregroundStyle(.red) }
            }
        }
        .navigationTitle(isNew ? "New flight" : "Edit flight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    flight.name = flight.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isNew { model.addFlight(flight) } else { model.updateFlight(flight) }
                    dismiss()
                }
                .disabled(blockingReason != nil)
            }
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(item: Binding(
            get: { legDraft.map { DraftBox(draft: $0) } },
            set: { legDraft = $0?.draft }
        )) { box in
            NavigationStack {
                LegEditorView(draft: box.draft) { leg in
                    if let i = flight.legs.firstIndex(where: { $0.id == leg.id }) {
                        flight.legs[i] = leg
                    } else {
                        flight.legs.append(leg)
                    }
                }
            }
        }
    }
}

private struct DraftBox: Identifiable {
    var draft: LegDraft
    var id: UUID { draft.id }
}
