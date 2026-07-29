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
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    profileCard(metrics)
                    calculationsCard(metrics)
                    goalCard(metrics)
                    notificationsCard(metrics)
                    appearanceCard(metrics)
                    privacyCard(metrics)
                    aboutCard(metrics)
                    Button("Start over", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Color.breatheDestructive).frame(maxWidth: .infinity, minHeight: 48)
                }.padding(.bottom, metrics.majorSpacing)
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

    private func profileCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("Quit profile", icon: "person.crop.circle", metrics: metrics) {
            DatePicker("I quit on", selection: $quitDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            Divider().overlay(Color.breatheDivider)
            Stepper("Cigarettes per day: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...80)
            Stepper("Cigarettes per pack: \(cigarettesPerPack)", value: $cigarettesPerPack, in: 1...40)
            BreathePrimaryButton(title: "Save changes", disabled: !hasChanges, action: save)
        }
    }

    private func calculationsCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("Currency and calculations", icon: "function", metrics: metrics) {
            ViewThatFits(in: .horizontal) {
                HStack { Text("Price per pack"); Spacer(); priceField }
                VStack(alignment: .leading, spacing: metrics.compactSpacing) { Text("Price per pack"); priceField }
            }
            Picker("Currency", selection: $currencyCode) { ForEach(currencies, id: \.self) { Text($0).tag($0) } }
            Text("These values only affect your progress estimates.").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var priceField: some View {
        TextField("Price", value: $pricePerPack, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
    }

    private func goalCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("Savings goal", icon: "target", metrics: metrics) {
            TextField("What are you saving for?", text: $goalName).textFieldStyle(.roundedBorder)
            ViewThatFits(in: .horizontal) {
                HStack { Text("Target"); Spacer(); goalAmountField }
                VStack(alignment: .leading, spacing: metrics.compactSpacing) { Text("Target"); goalAmountField }
            }
            BreatheSecondaryButton(title: "Save goal", action: saveGoal)
                .disabled(goalName.trimmingCharacters(in: .whitespaces).isEmpty || goalTarget <= 0)
            if environment.planStore.goal != nil {
                Button("Remove goal", role: .destructive, action: removeGoal).foregroundStyle(Color.breatheDestructive).frame(minHeight: 44)
            }
        }
    }

    private var goalAmountField: some View {
        HStack { TextField("Amount", value: $goalTarget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(currencyCode).foregroundStyle(Color.breatheTextSecondary) }
    }

    private func notificationsCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("Notifications", icon: "bell", metrics: metrics) {
            Toggle("Milestone reminders", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in Task { await updateNotifications(enabled: enabled) } }
            Text("Celebrate important recovery moments. You can change this anytime.").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func appearanceCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("App appearance", icon: "circle.lefthalf.filled", metrics: metrics) {
            ViewThatFits(in: .horizontal) { LabeledContent("Theme", value: "Follow System"); VStack(alignment: .leading) { Text("Theme"); Text("Follow System").foregroundStyle(Color.breatheTextSecondary) } }
            Text("Breathe automatically supports Light and Dark Mode.").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func privacyCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("Data and privacy", icon: "lock.shield", metrics: metrics) {
            Label("Your profile and craving history stay on this device.", systemImage: "iphone")
                .font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func aboutCard(_ metrics: AppLayoutMetrics) -> some View {
        settingsGroup("About", icon: "info.circle", metrics: metrics) {
            ViewThatFits(in: .horizontal) { LabeledContent("Version", value: appVersion); VStack(alignment: .leading) { Text("Version"); Text(appVersion).foregroundStyle(Color.breatheTextSecondary) } }
            Link(destination: URL(string: "https://github.com/alonaKostenkoiOS/Breathe")!) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right").frame(minHeight: 44)
            }.foregroundStyle(Color.breatheAccent)
        }
    }

    private func settingsGroup<Content: View>(_ title: LocalizedStringKey, icon: String, metrics: AppLayoutMetrics,
                                               @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            Label(title, systemImage: icon).font(AppTypography.sectionTitle(for: metrics.mode)).foregroundStyle(Color.breatheText).fixedSize(horizontal: false, vertical: true)
            BreatheCard { VStack(alignment: .leading, spacing: metrics.cardPadding) { content() } }
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
