import SwiftUI
import BreatheCore

/// Collects the smoking baseline and creates the ``QuitPlan`` that the rest
/// of the app derives everything from.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var quitDate = Date()
    @State private var cigarettesPerDay = 15
    @State private var cigarettesPerPack = 20
    @State private var pricePerPack = 12.0
    @State private var currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A few details and Breathe will track every hour, cigarette and dollar you reclaim.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("When did you quit?") {
                    DatePicker("Quit date", selection: $quitDate, in: ...Date())
                }
                Section("Your habit") {
                    Stepper("Cigarettes per day: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...80)
                    Stepper("Cigarettes per pack: \(cigarettesPerPack)", value: $cigarettesPerPack, in: 1...40)
                }
                Section("Cost") {
                    HStack {
                        Text("Price per pack")
                        Spacer()
                        TextField("Price", value: $pricePerPack, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(currencyCode)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Welcome to Breathe")
            .safeAreaInset(edge: .bottom) {
                Button(action: start) {
                    Text("Start tracking")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }

    private func start() {
        let plan = QuitPlan(
            quitDate: quitDate,
            cigarettesPerDay: cigarettesPerDay,
            cigarettesPerPack: cigarettesPerPack,
            pricePerPack: Decimal(pricePerPack),
            currencyCode: currencyCode
        )
        environment.planStore.save(plan)
    }
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment.preview())
}
