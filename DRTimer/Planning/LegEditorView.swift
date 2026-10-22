import SwiftUI
import DRCore

struct LegEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LegDraft
    @FocusState private var landmarkFocused: Bool
    private let onSave: (Leg) -> Void

    init(draft: LegDraft, onSave: @escaping (Leg) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Landmark") {
                TextField("e.g. Bridge", text: $draft.landmark)
                    .focused($landmarkFocused)
            }
            Section("Time to next landmark") {
                HStack(spacing: 0) {
                    wheel(value: $draft.minutes, range: 0...99, unit: "min")
                    wheel(value: $draft.seconds, range: 0...59, unit: "sec")
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
        .onAppear { landmarkFocused = true }
        .navigationTitle("Leg")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    /// Wheel selector over a numeric range, stored in the draft as text.
    private func wheel(value: Binding<String>, range: ClosedRange<Int>, unit: String) -> some View {
        let number = Binding<Int>(
            get: { Int(value.wrappedValue) ?? 0 },
            set: { value.wrappedValue = String($0) }
        )
        return HStack(spacing: 4) {
            Picker(unit, selection: number) {
                ForEach(range, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(unit)
        }
        .frame(maxWidth: .infinity)
    }
}
