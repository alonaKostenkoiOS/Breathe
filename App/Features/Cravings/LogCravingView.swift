import SwiftUI
import BreatheCore

/// Modal form for logging a craving and whether it was resisted.
struct LogCravingView: View {
    let onSave: (Int, Craving.Trigger, Bool, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var intensity = 3
    @State private var trigger: Craving.Trigger = .stress
    @State private var didResist = true
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Intensity") {
                    Stepper(value: $intensity, in: 1...5) {
                        HStack {
                            Text("Strength")
                            Spacer()
                            Text(String(repeating: "🔥", count: intensity))
                        }
                    }
                }
                Section("Trigger") {
                    Picker("Trigger", selection: $trigger) {
                        ForEach(Craving.Trigger.allCases, id: \.self) { trigger in
                            Text(trigger.label).tag(trigger)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Toggle("I resisted it 💪", isOn: $didResist)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log craving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(intensity, trigger, didResist, note)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

extension Craving.Trigger {
    var label: String {
        switch self {
        case .stress: "Stress"
        case .coffee: "Coffee"
        case .alcohol: "Alcohol"
        case .afterMeal: "After a meal"
        case .boredom: "Boredom"
        case .social: "Social"
        case .other: "Other"
        }
    }
}

#Preview {
    LogCravingView { _, _, _, _ in }
}
