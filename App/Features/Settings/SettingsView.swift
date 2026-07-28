import SwiftUI
import BreatheCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var quitDate = Date()
    @State private var cigarettesPerDay = 15
    @State private var cigarettesPerPack = 20
    @State private var pricePerPack = 12.0
    @State private var currencyCode = "USD"
    @State private var goalName = ""
    @State private var goalTarget = 0.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var didLoad = false
    @State private var showResetConfirmation = false
    @State private var showSavedConfirmation = false
    private let currencies = ["USD", "EUR", "GBP", "UAH", "PLN", "CZK"]

    var body: some View {
        NavigationStack {
            BreatheScreen {
                VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
                    profileCard
                    calculationsCard
                    goalCard
                    notificationsCard
                    appearanceCard
                    privacyCard
                    aboutCard
                    Button("Start over", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Color.breatheDestructive).frame(maxWidth: .infinity, minHeight: 48)
                }.padding(.bottom, BreatheSpacing.xl)
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.breatheBackground, for: .navigationBar)
            .onAppear(perform: loadIfNeeded)
            .confirmationDialog("Start over?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Start over", role: .destructive) { environment.planStore.reset() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This resets your quit plan. Your logged cravings are kept.") }
            .alert("Saved", isPresented: $showSavedConfirmation) { Button("OK", role: .cancel) {} }
            message: { Text("Your plan has been updated.") }
        }
    }

    private var profileCard: some View {
        settingsGroup("Quit profile", icon: "person.crop.circle") {
            DatePicker("I quit on", selection: $quitDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            Divider().overlay(Color.breatheDivider)
            Stepper("Cigarettes per day: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...80)
            Stepper("Cigarettes per pack: \(cigarettesPerPack)", value: $cigarettesPerPack, in: 1...40)
            BreathePrimaryButton(title: "Save changes", disabled: !hasChanges, action: save)
        }
    }

    private var calculationsCard: some View {
        settingsGroup("Currency and calculations", icon: "function") {
            HStack { Text("Price per pack"); Spacer(); TextField("Price", value: $pricePerPack, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100) }
            Picker("Currency", selection: $currencyCode) { ForEach(currencies, id: \.self) { Text($0).tag($0) } }
            Text("These values only affect your progress estimates.").font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private var goalCard: some View {
        settingsGroup("Savings goal", icon: "target") {
            TextField("What are you saving for?", text: $goalName).textFieldStyle(.roundedBorder)
            HStack { Text("Target"); Spacer(); TextField("Amount", value: $goalTarget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(currencyCode).foregroundStyle(Color.breatheTextSecondary) }
            BreatheSecondaryButton(title: "Save goal", action: saveGoal)
                .disabled(goalName.trimmingCharacters(in: .whitespaces).isEmpty || goalTarget <= 0)
            if environment.planStore.goal != nil {
                Button("Remove goal", role: .destructive, action: removeGoal).foregroundStyle(Color.breatheDestructive).frame(minHeight: 44)
            }
        }
    }

    private var notificationsCard: some View {
        settingsGroup("Notifications", icon: "bell") {
            Toggle("Milestone reminders", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in Task { await updateNotifications(enabled: enabled) } }
            Text("Celebrate important recovery moments. You can change this anytime.").font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private var appearanceCard: some View {
        settingsGroup("App appearance", icon: "circle.lefthalf.filled") {
            LabeledContent("Theme", value: "Follow System")
            Text("Breathe automatically supports Light and Dark Mode.").font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private var privacyCard: some View {
        settingsGroup("Data and privacy", icon: "lock.shield") {
            Label("Your profile and craving history stay on this device.", systemImage: "iphone")
                .font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private var aboutCard: some View {
        settingsGroup("About", icon: "info.circle") {
            LabeledContent("Version", value: appVersion)
            Link(destination: URL(string: "https://github.com/alonaKostenkoiOS/Breathe")!) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right").frame(minHeight: 44)
            }.foregroundStyle(Color.breatheAccent)
        }
    }

    private func settingsGroup<Content: View>(_ title: LocalizedStringKey, icon: String,
                                               @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            Label(title, systemImage: icon).font(.breatheSectionTitle).foregroundStyle(Color.breatheText)
            BreatheCard { VStack(alignment: .leading, spacing: BreatheSpacing.md) { content() } }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    private var hasChanges: Bool {
        guard let plan = environment.planStore.plan else { return true }
        return plan.quitDate != quitDate || plan.cigarettesPerDay != cigarettesPerDay || plan.cigarettesPerPack != cigarettesPerPack || plan.pricePerPack != Decimal(pricePerPack) || plan.currencyCode != currencyCode
    }
    private func loadIfNeeded() {
        guard !didLoad, let plan = environment.planStore.plan else { return }
        quitDate = plan.quitDate; cigarettesPerDay = plan.cigarettesPerDay; cigarettesPerPack = plan.cigarettesPerPack
        pricePerPack = NSDecimalNumber(decimal: plan.pricePerPack).doubleValue; currencyCode = plan.currencyCode
        if let goal = environment.planStore.goal { goalName = goal.name; goalTarget = NSDecimalNumber(decimal: goal.target).doubleValue }
        didLoad = true
    }
    private func save() {
        let plan = QuitPlan(quitDate: quitDate, cigarettesPerDay: cigarettesPerDay, cigarettesPerPack: cigarettesPerPack, pricePerPack: Decimal(pricePerPack), currencyCode: currencyCode)
        environment.planStore.save(plan); showSavedConfirmation = true; BreatheFeedback.success()
        if notificationsEnabled { Task { await scheduleMilestones(for: plan) } }
    }
    private func saveGoal() { environment.planStore.saveGoal(SavingsGoal(name: goalName, target: Decimal(goalTarget))); showSavedConfirmation = true; BreatheFeedback.success() }
    private func removeGoal() { environment.planStore.saveGoal(nil); goalName = ""; goalTarget = 0 }
    private func updateNotifications(enabled: Bool) async {
        guard enabled else { await environment.notificationService.cancelAll(); return }
        let granted = await environment.notificationService.requestAuthorization()
        guard granted, let plan = environment.planStore.plan else { notificationsEnabled = false; return }
        await scheduleMilestones(for: plan)
    }
    private func scheduleMilestones(for plan: QuitPlan) async {
        await environment.notificationService.scheduleMilestones(for: plan, using: environment.milestoneEngine, now: environment.dateProvider.now())
    }
}

#Preview { SettingsView().environment(AppEnvironment.preview()) }
