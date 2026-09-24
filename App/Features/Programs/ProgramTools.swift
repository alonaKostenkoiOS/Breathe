import SwiftUI
import BreatheCore

struct IfThenPlanEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let program: RecoveryProgram
    @State private var ifText = ""
    @State private var thenText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("plan.if_then.if_label") { TextField("plan.if_then.if_placeholder", text: $ifText, axis: .vertical) }
                Section("plan.if_then.then_label") { TextField("plan.if_then.then_placeholder", text: $thenText, axis: .vertical) }
                Section { Text("plan.if_then.privacy").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("plan.if_then.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(ifText.trimmed.isEmpty || thenText.trimmed.isEmpty) }
            }
        }
    }
    private func save() { environment.recoveryStore.save(IfThenPlan(programInstanceID: program.id, ifText: ifText.trimmed, thenText: thenText.trimmed)); dismiss() }
}

struct PauseListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let program: RecoveryProgram
    @State private var item = ""; @State private var price = 0.0; @State private var reason = ""
    @State private var waitingHours = 24
    private var entries: [PauseListItem] { environment.recoveryStore.state.pauseList.filter { $0.programInstanceID == program.id }.sorted { $0.dateAdded > $1.dateAdded } }

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                BreatheSectionHeader(title: "spending.pause_list.title", detail: "spending.pause_list.detail")
                BreatheCard { VStack(alignment: .leading, spacing: metrics.cardPadding) {
                    TextField("spending.pause_list.item", text: $item).textFieldStyle(.roundedBorder)
                    TextField("spending.pause_list.price", value: $price, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    TextField("spending.pause_list.reason", text: $reason, axis: .vertical).textFieldStyle(.roundedBorder)
                    Picker("spending.pause_list.wait", selection: $waitingHours) { Text("10 min").tag(0); Text("24 hours").tag(24); Text("72 hours").tag(72) }
                    BreathePrimaryButton(title: "spending.pause_list.add", disabled: item.trimmed.isEmpty || price < 0, action: add)
                } }
                ForEach(entries) { entry in BreatheCard(tint: .breatheSurfaceSoft) { VStack(alignment: .leading) {
                    Text(entry.item).font(.headline); Text(entry.price, format: .currency(code: entry.currencyCode)); Text(entry.reviewAt, format: .dateTime.day().month().hour().minute()).foregroundStyle(Color.breatheTextSecondary)
                } } }
            }.padding(.bottom, metrics.majorSpacing) }
            .navigationTitle("spending.pause_list.title")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
    private func add() {
        let seconds = waitingHours == 0 ? 600.0 : Double(waitingHours * 3_600)
        let currency = Locale.current.currency?.identifier ?? "USD"
        environment.recoveryStore.save(PauseListItem(programInstanceID: program.id, item: item.trimmed, price: Decimal(price), currencyCode: currency, reason: reason.trimmed.nilIfEmpty, reviewAt: .now.addingTimeInterval(seconds)))
        item = ""; price = 0; reason = ""; BreatheFeedback.success()
    }
}

struct RiskWindowEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let program: RecoveryProgram
    @State private var time = Date()
    var body: some View { NavigationStack { Form {
        Section("risk_window.manual.title") { DatePicker("risk_window.time", selection: $time, displayedComponents: .hourAndMinute) }
        Section { Text("risk_window.manual.detail").font(.caption).foregroundStyle(.secondary) }
    }.navigationTitle("risk_window.title").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save") { let components = Calendar.current.dateComponents([.hour, .minute], from: time); environment.recoveryStore.save(RiskWindow(programInstanceID: program.id, localHour: components.hour ?? 12, localMinute: components.minute ?? 0)); dismiss() } }
    } } }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}
