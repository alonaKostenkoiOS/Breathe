import SwiftUI
import BreatheCore

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.locale) private var locale
    @State private var draft: OnboardingDraft?
    @State private var direction = 1
    @State private var priceText = ""
    @State private var goalAmountText = ""
    @State private var goalName = ""
    @State private var goalEmoji = ""
    @State private var errorKey: LocalizedStringKey?

    private var step: OnboardingStep { OnboardingStep(rawValue: draft?.step ?? 0) ?? .welcome }
    private var progress: Double { Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.breatheBackground.ignoresSafeArea()
                if let draft { screen(draft) } else { ProgressView() }
            }
            .safeAreaInset(edge: .top) {
                if step != .welcome { BreatheProgressBar(value: progress).padding(.horizontal, BreatheSpacing.screen) }
            }
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        BreatheIconButton(icon: "chevron.left", label: "Back", action: back)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: step)
        }
        .onAppear(perform: restore)
        .onChange(of: draft) { _, value in if let value { environment.planStore.saveDraft(value) } }
    }

    @ViewBuilder private func screen(_ value: OnboardingDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
                switch step {
                case .welcome: welcome
                case .status: status
                case .quitDate: quitDate
                case .routine: previousRoutine
                case .firstCigarette: firstCigarette
                case .triggers: triggers
                case .routineTiming: routineTiming
                case .motivation: motivation
                case .savingsGoal: savingsGoal
                case .smartSupport: smartSupport
                case .notifications: notifications
                case .summary: summary(value.profile)
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(BreatheSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .id(step)
        .transition(.asymmetric(
            insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
            Image("OnboardingHero")
                .resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 330)
                .clipShape(RoundedRectangle(cornerRadius: BreatheRadius.hero))
                .overlay(alignment: .topLeading) {
                    Label("Breathe", systemImage: "leaf.fill").font(.headline).foregroundStyle(Color.breatheAccent)
                        .padding(.horizontal, BreatheSpacing.md).frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule()).padding(BreatheSpacing.md)
                }
                .accessibilityLabel("A peaceful path through green hills toward sunrise")
            title("Quit smoking with a plan that adapts to you",
                  "Breathe tracks your progress, learns your difficult moments, and helps you get through cravings before they turn into slips.")
            primary("Get Started") { environment.onboardingAnalytics.track(.started); advance() }
            Label("Your data stays on your device.", systemImage: "lock.fill")
                .font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Where are you in your journey?")
            choice("I already quit", selected: draft?.journeyStatus == .alreadyQuit) {
                draft?.journeyStatus = .alreadyQuit
            }
            choice("I’m quitting today", selected: draft?.journeyStatus == .quittingToday) {
                draft?.journeyStatus = .quittingToday
                draft?.profile.quitDate = environment.dateProvider.now()
            }
            primary("Continue", disabled: draft?.journeyStatus == nil, action: advance)
        }
    }

    private var quitDate: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("When did you quit?", "We’ll use this date to calculate your smoke-free progress.")
            DatePicker("Quit date & time", selection: binding(\.quitDate),
                       in: ...environment.dateProvider.now(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
            validation
            primary("Continue") { advance() }
        }
    }

    private var previousRoutine: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Tell us about your previous routine", "This helps calculate cigarettes avoided and money saved.")
            BreatheCard {
                VStack(spacing: 16) {
                    Stepper("Cigarettes per day: \(draft?.profile.cigarettesPerDay ?? 0)",
                            value: binding(\.cigarettesPerDay), in: 1...80)
                    Stepper("Cigarettes per pack: \(draft?.profile.cigarettesPerPack ?? 0)",
                            value: binding(\.cigarettesPerPack), in: 1...40)
                    TextField("Price per pack", text: $priceText).keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Price per pack")
                    Picker("Currency", selection: binding(\.currencyCode)) {
                        ForEach(currencyCodes, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            validation
            primary("Continue") {
                guard let amount = decimal(priceText), OnboardingValidation.isValidPrice(amount) else {
                    errorKey = "Enter a valid price greater than zero."; return
                }
                draft?.profile.packPrice = amount; advance()
            }
        }
    }

    private var firstCigarette: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("When did you usually smoke your first cigarette?")
            ForEach(FirstCigaretteTiming.allCases, id: \.self) { item in
                choice(firstTimingKey(item), selected: draft?.profile.firstCigaretteTiming == item) {
                    draft?.profile.firstCigaretteTiming = item
                }
            }
            primary("Continue", action: advance)
        }
    }

    private var triggers: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("When were you most likely to smoke?", "Choose all situations that were part of your routine.")
            BreatheFlowLayout(spacing: 10) {
                ForEach(SmokingTrigger.allCases, id: \.self) { item in
                    chip(triggerKey(item), selected: draft?.profile.triggers.contains(item) == true) {
                        toggle(item, in: &draft!.profile.triggers)
                    }
                }
            }
            primary("Continue", action: advance)
        }
    }

    private var routineTiming: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("When do these moments usually happen?")
            if relevantEvents.isEmpty { Text("You can add routine times later.").foregroundStyle(Color.breatheTextSecondary) }
            ForEach(relevantEvents, id: \.self) { type in routineEventRow(type) }
            primary("Continue", action: advance)
            secondary("Skip for now") { skip() }
        }
    }

    private var motivation: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("What are you quitting for?")
            BreatheFlowLayout(spacing: 10) {
                ForEach(QuitMotivation.allCases, id: \.self) { item in
                    chip(motivationKey(item), selected: draft?.profile.motivations.contains(item) == true) {
                        toggle(item, in: &draft!.profile.motivations)
                    }
                }
            }
            TextField("I want to quit because…", text: reasonBinding, axis: .vertical)
                .lineLimit(3...5).textFieldStyle(.roundedBorder)
            Text("\(draft?.profile.personalReason?.count ?? 0)/150").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing).accessibilityLabel("Personal reason character count")
            primary("Continue", action: advance)
        }
    }

    private var savingsGoal: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("What would you love to save for?")
            TextField("Goal name", text: $goalName).textFieldStyle(.roundedBorder)
            HStack {
                TextField("Emoji", text: $goalEmoji).frame(width: 72).textFieldStyle(.roundedBorder)
                TextField("Target amount", text: $goalAmountText).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
            }
            validation
            primary("Continue") {
                guard !goalName.trimmingCharacters(in: .whitespaces).isEmpty,
                      let amount = decimal(goalAmountText), amount > 0 else {
                    errorKey = "Enter a goal name and valid target amount."; return
                }
                draft?.profile.savingsGoal = SavingsGoal(name: goalName, target: amount)
                draft?.profile.savingsGoalEmoji = goalEmoji.isEmpty ? nil : String(goalEmoji.prefix(2))
                advance()
            }
            secondary("Skip for now") { draft?.profile.savingsGoal = nil; skip() }
        }
    }

    private var smartSupport: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Breathe will learn your difficult moments",
                  "During the first week, we’ll use common craving patterns and the routine you selected. As you log cravings, reminders will become more personal and accurate.")
            supportRow(1, "Log a craving", "square.and.pencil")
            supportRow(2, "Discover your patterns", "chart.bar.fill")
            supportRow(3, "Get support before difficult moments", "bell.badge.fill")
            primary("Continue", action: advance)
        }
    }

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Get support at the right moment",
                  "Breathe can remind you before your usual smoking moments and celebrate important milestones.")
            Toggle("Difficult-moment alerts", isOn: binding(\.notificationPreferences.difficultMoments))
            Toggle("Milestone reminders", isOn: binding(\.notificationPreferences.milestones))
            Toggle("Daily check-in", isOn: binding(\.notificationPreferences.dailyCheckIn))
            primary("Enable Smart Reminders") { Task { await requestNotifications() } }
            secondary("Not Now") { skip() }
        }
    }

    private func summary(_ profile: QuitProfile) -> some View {
        let weekly = (profile.packPrice / Decimal(profile.cigarettesPerPack)) * Decimal(profile.cigarettesPerDay * 7)
        let next = environment.milestoneEngine.nextMilestone(for: profile.quitPlan, at: environment.dateProvider.now())
        return VStack(alignment: .leading, spacing: 18) {
            Image("PlanReadyBotanical").resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 190).accessibilityHidden(true)
            title("Your smoke-free plan is ready")
            summaryRow("Estimated cigarettes avoided per day", "\(profile.cigarettesPerDay)")
            summaryRow("Estimated weekly savings", weekly.formatted(.currency(code: profile.currencyCode)))
            if let next { summaryRow("First upcoming health milestone", String(localized: String.LocalizationValue(next.milestone.title))) }
            if !profile.triggers.isEmpty {
                summaryRow("Selected high-risk situations", profile.triggers.map { String(localized: String.LocalizationValue(triggerKey($0))) }.sorted().joined(separator: ", "))
            }
            if let reason = profile.personalReason { summaryRow("Your reason", reason) }
            if environment.dateProvider.now().timeIntervalSince(profile.quitDate) < 3 * 86_400 {
                Text("Your first three days may feel more challenging. We’ll support you around the moments you selected.")
                    .padding().background(Color.breatheAccentSoft, in: RoundedRectangle(cornerRadius: BreatheRadius.card))
            }
            primary("Start My Journey", action: complete)
        }
    }

    // MARK: State and navigation

    private func restore() {
        if let saved = environment.planStore.onboardingDraft { draft = saved }
        else {
            let profile = QuitProfile(quitDate: environment.dateProvider.now(), cigarettesPerDay: 15,
                                      packPrice: 12, currencyCode: CurrencyResolver.currencyCode(for: locale))
            draft = OnboardingDraft(profile: profile)
        }
        priceText = NSDecimalNumber(decimal: draft?.profile.packPrice ?? 12).stringValue
        if let goal = draft?.profile.savingsGoal {
            goalName = goal.name; goalAmountText = NSDecimalNumber(decimal: goal.target).stringValue
            goalEmoji = draft?.profile.savingsGoalEmoji ?? ""
        }
        environment.onboardingAnalytics.track(.stepViewed(step: step.rawValue))
    }

    private func advance() {
        guard let next = step.next(status: draft?.journeyStatus) else { return }
        environment.onboardingAnalytics.track(.stepCompleted(step: step.rawValue))
        direction = 1; errorKey = nil; draft?.step = next.rawValue
        environment.onboardingAnalytics.track(.stepViewed(step: next.rawValue))
    }

    private func back() {
        guard let previous = step.previous(status: draft?.journeyStatus) else { return }
        direction = -1; errorKey = nil; draft?.step = previous.rawValue
    }

    private func skip() { environment.onboardingAnalytics.track(.skipped(step: step.rawValue)); advance() }

    private func complete() {
        guard var profile = draft?.profile else { return }
        profile.personalReason = profile.personalReason.map { String($0.prefix(150)) }
        environment.planStore.completeOnboarding(with: profile, at: environment.dateProvider.now())
        environment.onboardingAnalytics.track(.completed)
    }

    private func requestNotifications() async {
        environment.onboardingAnalytics.track(.notificationPermissionRequested)
        let granted = await environment.notificationService.requestAuthorization()
        environment.onboardingAnalytics.track(.notificationPermissionResult(granted: granted))
        if granted, draft?.profile.notificationPreferences.milestones == true, let plan = draft?.profile.quitPlan {
            await environment.notificationService.scheduleMilestones(for: plan, using: environment.milestoneEngine,
                                                                      now: environment.dateProvider.now())
        }
        advance() // denial never blocks completion
    }

    // MARK: Components

    private func title(_ heading: LocalizedStringKey, _ detail: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading).font(.breatheLargeTitle).accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).font(.breatheBody).foregroundStyle(Color.breatheTextSecondary) }
        }
    }

    private func primary(_ label: LocalizedStringKey, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        BreathePrimaryButton(title: label, disabled: disabled, action: action)
    }

    private func secondary(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        BreatheSecondaryButton(title: label, action: action)
    }

    private func choice(_ label: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        BreatheSelectionCard(title: label, selected: selected) { action(); BreatheFeedback.selection() }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        BreatheChip(title: LocalizedStringKey(label), selected: selected) { action(); BreatheFeedback.selection() }
    }

    private func supportRow(_ number: Int, _ text: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Text("\(number)").font(.headline).frame(width: 36, height: 36).background(Color.breatheAccentSoft, in: Circle())
            Label { Text(text) } icon: { Image(systemName: icon).foregroundStyle(Color.breatheAccent) }
        }.accessibilityElement(children: .combine)
    }

    private func summaryRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        BreatheCard(tint: .breatheSurfaceSoft) {
            VStack(alignment: .leading, spacing: 4) { Text(label).font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary); Text(value).font(.headline) }
        }
    }

    @ViewBuilder private var validation: some View {
        if let errorKey { Label { Text(errorKey) } icon: { Image(systemName: "exclamationmark.circle") }.foregroundStyle(Color.breatheDestructive).font(.footnote) }
    }

    private var reasonBinding: Binding<String> { Binding(get: { draft?.profile.personalReason ?? "" }, set: { draft?.profile.personalReason = String($0.prefix(150)) }) }
    private func binding<T>(_ path: WritableKeyPath<QuitProfile, T>) -> Binding<T> {
        Binding(get: { draft!.profile[keyPath: path] }, set: { draft!.profile[keyPath: path] = $0 })
    }

    private func decimal(_ string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var currencyCodes: [String] {
        Array(Set([CurrencyResolver.currencyCode(for: locale), "UAH", "USD", "EUR", "GBP", "PLN", "CZK"])).sorted()
    }

    private var relevantEvents: [RoutineEventType] {
        var items: Set<RoutineEventType> = []
        let selected = draft?.profile.triggers ?? []
        if selected.contains(.morningCoffee) { items.insert(.morningCoffee); items.insert(.breakfast) }
        if selected.contains(.afterMeals) { items.formUnion([.breakfast, .lunch, .dinner]) }
        if selected.contains(.workBreaks) { items.insert(.workBreak) }
        if selected.contains(.beforeBed) { items.insert(.bedtime) }
        if selected.contains(.alcohol) || selected.contains(.socialSituations) { items.insert(.evening) }
        return RoutineEventType.allCases.filter(items.contains)
    }

    private func routineEventRow(_ type: RoutineEventType) -> some View {
        let existing = draft?.profile.routineEvents.first(where: { $0.type == type })
        let enabled = existing?.isEnabled ?? false
        return VStack(alignment: .leading) {
            Toggle(LocalizedStringKey(routineEventKey(type)), isOn: Binding(get: { enabled }, set: { setEvent(type, enabled: $0) }))
            if enabled {
                DatePicker("Time", selection: Binding(get: { date(for: existing) }, set: { setEvent(type, date: $0) }), displayedComponents: .hourAndMinute)
            }
        }.padding().background(Color.breatheSurface, in: RoundedRectangle(cornerRadius: BreatheRadius.card))
            .overlay(RoundedRectangle(cornerRadius: BreatheRadius.card).stroke(Color.breatheDivider))
    }

    private func setEvent(_ type: RoutineEventType, enabled: Bool? = nil, date: Date? = nil) {
        guard var profile = draft?.profile else { return }
        let index = profile.routineEvents.firstIndex(where: { $0.type == type })
        let components = Calendar.current.dateComponents([.hour, .minute], from: date ?? self.date(for: index.map { profile.routineEvents[$0] }))
        let event = RoutineEvent(id: index.map { profile.routineEvents[$0].id } ?? UUID(), type: type,
                                 localHour: components.hour ?? 9, localMinute: components.minute ?? 0,
                                 isEnabled: enabled ?? true)
        if let index { profile.routineEvents[index] = event } else { profile.routineEvents.append(event) }
        draft?.profile = profile
    }

    private func date(for event: RoutineEvent?) -> Date {
        Calendar.current.date(bySettingHour: event?.localHour ?? 9, minute: event?.localMinute ?? 0,
                              second: 0, of: environment.dateProvider.now()) ?? environment.dateProvider.now()
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) { if set.contains(value) { set.remove(value) } else { set.insert(value) } }
}

private func firstTimingKey(_ item: FirstCigaretteTiming) -> LocalizedStringKey {
    switch item { case .within5Minutes: "Within 5 minutes after waking"; case .within30Minutes: "Within 30 minutes"; case .within60Minutes: "Within 60 minutes"; case .after60Minutes: "More than 60 minutes later" }
}
private func triggerKey(_ item: SmokingTrigger) -> String {
    switch item { case .morningCoffee: "Morning coffee"; case .afterMeals: "After meals"; case .workBreaks: "Work breaks"; case .stress: "Stress"; case .boredom: "Boredom"; case .alcohol: "Alcohol"; case .driving: "Driving"; case .socialSituations: "Social situations"; case .seeingOthersSmoke: "Seeing others smoke"; case .beforeBed: "Before bed"; case .other: "Other" }
}
private func motivationKey(_ item: QuitMotivation) -> String {
    switch item { case .betterHealth: "Better health"; case .saveMoney: "Save money"; case .familyRelationships: "Family and relationships"; case .moreEnergy: "More energy"; case .appearance: "Appearance"; case .freedom: "Freedom from addiction"; case .futureFamily: "Future family"; case .personal: "Something personal" }
}
private func routineEventKey(_ item: RoutineEventType) -> String {
    switch item { case .morningCoffee: "Morning coffee"; case .breakfast: "Breakfast"; case .lunch: "Lunch"; case .workBreak: "Work break"; case .dinner: "Dinner"; case .evening: "Evening"; case .bedtime: "Bedtime" }
}

#Preview { OnboardingView().environment(AppEnvironment.preview()) }
