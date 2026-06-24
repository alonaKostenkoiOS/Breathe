import SwiftUI
import BreatheCore

/// Lets the user adjust the plan that every statistic is derived from, and
/// start over. Edits flow straight back into `PlanStore`, so the dashboard,
/// recovery timeline and widget all reflect the change.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var quitDate = Date()
    @State private var cigarettesPerDay = 15
    @State private var cigarettesPerPack = 20
    @State private var pricePerPack = 12.0
    @State private var currencyCode = "USD"

    @State private var didLoad = false
    @State private var showResetConfirmation = false
    @State private var showSavedConfirmation = false

    private let currencies = ["USD", "EUR", "GBP", "UAH", "PLN", "CZK"]

    var body: some View {
        NavigationStack {
            Form {
                habitSection
                costSection
                quitDateSection

                Section {
                    Button("Save changes", action: save)
                        .frame(maxWidth: .infinity)
                        .disabled(!hasChanges)
                }

                Section {
                    Button("Start over", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("Clears your plan and returns to the welcome screen. Your logged cravings are kept.")
                }

                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear(perform: loadIfNeeded)
            .confirmationDialog(
                "Start over?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Start over", role: .destructive) { environment.planStore.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets your quit plan. You'll set it up again from scratch.")
            }
            .alert("Saved", isPresented: $showSavedConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your plan has been updated.")
            }
        }
    }

    // MARK: Sections

    private var habitSection: some View {
        Section("Your habit") {
            Stepper("Cigarettes per day: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...80)
            Stepper("Cigarettes per pack: \(cigarettesPerPack)", value: $cigarettesPerPack, in: 1...40)
        }
    }

    private var costSection: some View {
        Section("Cost") {
            HStack {
                Text("Price per pack")
                Spacer()
                TextField("Price", value: $pricePerPack, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Currency", selection: $currencyCode) {
                ForEach(currencies, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var quitDateSection: some View {
        Section("Quit date & time") {
            DatePicker(
                "I quit on",
                selection: $quitDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            Link(destination: URL(string: "https://github.com/alonaKostenkoiOS/Breathe")!) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    // MARK: Logic

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Whether the edited fields differ from the stored plan.
    private var hasChanges: Bool {
        guard let plan = environment.planStore.plan else { return true }
        return plan.quitDate != quitDate
            || plan.cigarettesPerDay != cigarettesPerDay
            || plan.cigarettesPerPack != cigarettesPerPack
            || plan.pricePerPack != Decimal(pricePerPack)
            || plan.currencyCode != currencyCode
    }

    private func loadIfNeeded() {
        guard !didLoad, let plan = environment.planStore.plan else { return }
        quitDate = plan.quitDate
        cigarettesPerDay = plan.cigarettesPerDay
        cigarettesPerPack = plan.cigarettesPerPack
        pricePerPack = NSDecimalNumber(decimal: plan.pricePerPack).doubleValue
        currencyCode = plan.currencyCode
        didLoad = true
    }

    private func save() {
        environment.planStore.save(
            QuitPlan(
                quitDate: quitDate,
                cigarettesPerDay: cigarettesPerDay,
                cigarettesPerPack: cigarettesPerPack,
                pricePerPack: Decimal(pricePerPack),
                currencyCode: currencyCode
            )
        )
        showSavedConfirmation = true
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.preview())
}
