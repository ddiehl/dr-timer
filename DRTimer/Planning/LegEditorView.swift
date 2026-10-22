import SwiftUI
import DRCore

struct LegEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LegDraft
    private let onSave: (Leg) -> Void

    init(draft: LegDraft, onSave: @escaping (Leg) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Landmark") {
                TextField("e.g. Bridge", text: $draft.landmark)
            }
            Section("Time to next landmark") {
                HStack {
                    TextField("min", text: $draft.minutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("min")
                    TextField("sec", text: $draft.seconds)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("sec")
                }
            }
            if let message = draft.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            Section {
                Button("Save leg") {
                    if let leg = draft.leg {
                        onSave(leg)
                        dismiss()
                    }
                }
                .disabled(draft.leg == nil)
            }
        }
        .navigationTitle("Leg")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
