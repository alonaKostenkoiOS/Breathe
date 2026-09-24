import SwiftUI
import BreatheCore

extension RecoveryProgramID {
    var definition: RecoveryProgramDefinition { RecoveryProgramCatalog.definition(self) }
    var nameKey: LocalizedStringKey { LocalizedStringKey(definition.nameKey) }
    var descriptionKey: LocalizedStringKey { LocalizedStringKey(definition.descriptionKey) }
}

struct ProgramSelectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: RecoveryProgramID?

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    BreatheSectionHeader(title: "program.selection.title", detail: "program.selection.detail")
                    ForEach(RecoveryProgramID.allCases) { id in
                        let definition = id.definition
                        BreatheSelectionCard(title: id.nameKey, detail: id.descriptionKey,
                                             icon: definition.iconName, selected: selection == id) {
                            selection = id; BreatheFeedback.selection()
                        }
                    }
                    BreatheBanner(icon: "lock.shield.fill", title: "privacy.local.title",
                                  message: "privacy.local.detail", tint: .breatheSky)
                    BreathePrimaryButton(title: "program.selection.continue", disabled: selection == nil) {
                        if let selection { _ = environment.recoveryStore.start(selection) }
                    }
                }.padding(.bottom, metrics.majorSpacing)
            }.navigationTitle("Breathe")
        }
    }
}

struct ProgramSafetyGate: View {
    @Environment(AppEnvironment.self) private var environment
    let program: RecoveryProgram
    @State private var alcoholAnswers = AlcoholSafetyAnswers()
    @State private var gamblingConcern = false
    @State private var gamblingDanger = false
    @State private var escalation: SafetyEscalation?

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    BreatheSectionHeader(title: program.programID == .alcohol ? "alcohol.safety.title" : "gambling.safety.title",
                                         detail: program.programID == .alcohol ? "alcohol.safety.detail" : "gambling.safety.detail")
                    if program.programID == .alcohol { alcoholQuestions(metrics) } else { gamblingQuestions(metrics) }
                    if let escalation, escalation != .none { safetyMessage(escalation) }
                    BreathePrimaryButton(title: "safety.review.action", action: review)
                    if escalation != nil {
                        BreatheSecondaryButton(title: "safety.acknowledge.action") {
                            environment.recoveryStore.acknowledgeSafety(for: program.programID)
                        }
                    }
                }.padding(.bottom, metrics.majorSpacing)
            }.navigationTitle(program.programID.nameKey)
        }
    }

    private func alcoholQuestions(_ metrics: AppLayoutMetrics) -> some View {
        BreatheCard { VStack(alignment: .leading, spacing: metrics.cardPadding) {
            Toggle("alcohol.safety.heavy_use", isOn: $alcoholAnswers.frequentHeavyUse)
            Toggle("alcohol.safety.withdrawal", isOn: $alcoholAnswers.previousWithdrawal)
            Toggle("alcohol.safety.shaking", isOn: $alcoholAnswers.shakingOrSweating)
            Toggle("alcohol.safety.seizure", isOn: $alcoholAnswers.previousSeizure)
            Toggle("alcohol.safety.confusion", isOn: $alcoholAnswers.hallucinationsOrConfusion)
            Toggle("alcohol.safety.normal", isOn: $alcoholAnswers.drinksToFeelNormal)
            Toggle("alcohol.safety.pregnancy", isOn: $alcoholAnswers.pregnancy)
            Toggle("alcohol.safety.emergency", isOn: $alcoholAnswers.currentEmergency)
        } }
    }

    private func gamblingQuestions(_ metrics: AppLayoutMetrics) -> some View {
        BreatheCard { VStack(alignment: .leading, spacing: metrics.cardPadding) {
            Toggle("gambling.safety.self_harm", isOn: $gamblingConcern)
            Toggle("gambling.safety.immediate_danger", isOn: $gamblingDanger)
            Text("gambling.safety.resources_free").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
        } }
    }

    @ViewBuilder private func safetyMessage(_ value: SafetyEscalation) -> some View {
        let emergency = value == .emergency
        BreatheBanner(icon: emergency ? "cross.case.fill" : "person.crop.circle.badge.exclamationmark",
                      title: emergency ? "safety.emergency.title" : "safety.professional.title",
                      message: program.programID == .alcohol ? "alcohol.safety.warning" : "gambling.safety.warning",
                      tint: emergency ? .breathePeach : .breatheYellow)
        if emergency {
            Link(destination: URL(string: "https://findahelpline.com")!) { Label("safety.emergency.action", systemImage: "phone.fill").frame(minHeight: 44) }
        }
    }

    private func review() {
        escalation = program.programID == .alcohol
            ? environment.safetyService.alcoholEscalation(alcoholAnswers)
            : environment.safetyService.gamblingEscalation(selfHarmConcern: gamblingConcern, immediateDanger: gamblingDanger)
    }
}

struct ProgramHomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showRescue = false
    @State private var showMigration = false
    @State private var showPlan = false
    @State private var showPauseList = false
    @State private var showRiskWindow = false
    private var program: RecoveryProgram? { environment.recoveryStore.primaryProgram }

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                if let program {
                    VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                        hero(program, metrics)
                        rescue(program, metrics)
                        nextStep(program, metrics)
                        tools(program, metrics)
                        if let plan = environment.recoveryStore.state.plans.first(where: { $0.programInstanceID == program.id && !$0.isArchived }) {
                            BreatheBanner(icon: "arrow.triangle.branch", title: "plan.if_then.title",
                                          message: LocalizedStringKey("If \(plan.ifText), then \(plan.thenText)"), tint: .breatheYellow)
                        }
                        insight(program, metrics)
                    }.padding(.bottom, metrics.majorSpacing)
                }
            }.navigationTitle("Home")
        }
        .fullScreenCover(isPresented: $showRescue) { ProgramRescueView(program: program!) }
        .sheet(isPresented: $showPlan) { if let program { IfThenPlanEditorView(program: program) } }
        .sheet(isPresented: $showPauseList) { if let program { PauseListView(program: program) } }
        .sheet(isPresented: $showRiskWindow) { if let program { RiskWindowEditorView(program: program) } }
        .onAppear {
            if program?.programID == .nicotine, !environment.recoveryStore.state.didExplainPlatformMigration { showMigration = true }
        }
        .alert("platform.migration.title", isPresented: $showMigration) {
            Button("OK") { environment.recoveryStore.markMigrationExplanationSeen() }
        } message: { Text("platform.migration.detail") }
    }

    private func tools(_ program: RecoveryProgram, _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard { VStack(alignment: .leading, spacing: metrics.compactSpacing) {
            BreatheSecondaryButton(title: "plan.if_then.create", icon: "arrow.triangle.branch") { showPlan = true }
            BreatheSecondaryButton(title: "risk_window.create", icon: "clock.badge") { showRiskWindow = true }
            if program.programID == .spending { BreatheSecondaryButton(title: "spending.pause_list.open", icon: "cart.badge.clock") { showPauseList = true } }
            if program.programID == .digital { Text("digital.screen_time.fallback").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary) }
        } }
    }

    private func hero(_ program: RecoveryProgram, _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
            VStack(alignment: .leading, spacing: metrics.cardPadding) {
                Label(program.programID.nameKey, systemImage: program.programID.definition.iconName).foregroundStyle(Color.breatheAccent).font(.headline)
                Text("brand.regain_control").font(AppTypography.heroTitle(for: metrics.mode)).fixedSize(horizontal: false, vertical: true)
                Text(program.programID.descriptionKey).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rescue(_ program: RecoveryProgram, _ metrics: AppLayoutMetrics) -> some View {
        Button { showRescue = true } label: {
            BreatheCard { HStack(spacing: metrics.cardPadding) {
                Image(systemName: "wind").font(.title2).foregroundStyle(Color.breatheAccent).frame(width: 44, height: 44).background(Color.breatheAccentSoft, in: Circle())
                VStack(alignment: .leading) { Text("rescue.start").font(.headline); Text("rescue.start.detail").foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true) }
                Spacer(); Image(systemName: "chevron.right")
            } }
        }.buttonStyle(.plain).accessibilityHint("rescue.start.hint")
    }

    private func nextStep(_ program: RecoveryProgram, _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "home.next_step.title")
            BreatheBanner(icon: "arrow.forward.circle.fill", title: "home.prepare.title",
                          message: LocalizedStringKey(nextStepKey(program.programID)), tint: .breatheSky)
        }
    }

    private func insight(_ program: RecoveryProgram, _ metrics: AppLayoutMetrics) -> some View {
        let episodes = environment.recoveryStore.state.urges.filter { $0.programInstanceID == program.id }
        return VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "home.insight.title")
            BreatheCard { Text(episodes.isEmpty ? "insight.empty" : "insight.observation")
                    .foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private func nextStepKey(_ id: RecoveryProgramID) -> String { switch id {
    case .nicotine: "home.next.nicotine"; case .digital: "home.next.digital"; case .spending: "home.next.spending"; case .alcohol: "home.next.alcohol"; case .gambling: "home.next.gambling" } }
}

struct ProgramRescueView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let program: RecoveryProgram
    @State private var intensity = 3
    @State private var stage = 0
    @State private var selectedStrategy = ""
    @State private var initialDate = Date()
    @State private var remaining = 60
    @State private var helpful: Bool?

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(spacing: metrics.sectionSpacing) {
                    HStack { BreatheIconButton(icon: "xmark", label: "Close", action: { dismiss() }); Spacer(); Text("rescue.title").font(.headline); Spacer(); Color.clear.frame(width: 44) }
                    if stage == 0 { checkIn(metrics) } else if stage == 1 { exercise(metrics) } else { reflection(metrics) }
                }.padding(.bottom, metrics.majorSpacing)
            }.toolbar(.hidden, for: .navigationBar)
        }
    }

    private func checkIn(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            BreatheSectionHeader(title: "rescue.check_in.title", detail: "rescue.check_in.detail")
            HStack { ForEach(1...5, id: \.self) { value in
                Button("\(value)") { intensity = value }.frame(maxWidth: .infinity, minHeight: 52)
                    .background(intensity == value ? Color.breatheAccentSoft : .breatheSurface,
                                in: RoundedRectangle(cornerRadius: metrics.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: metrics.controlRadius).stroke(intensity == value ? Color.breatheAccent : .breatheDivider, lineWidth: intensity == value ? 2 : 1))
            } }
            BreathePrimaryButton(title: "rescue.begin", action: begin)
        }
    }

    private func exercise(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            Image(systemName: strategySymbol).font(.system(size: 54)).foregroundStyle(Color.breatheAccent)
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
            Text(LocalizedStringKey("strategy.\(selectedStrategy).title")).font(AppTypography.heroTitle(for: metrics.mode)).multilineTextAlignment(.center)
            Text(LocalizedStringKey("strategy.\(selectedStrategy).instruction")).font(AppTypography.body(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(Measurement(value: Double(remaining), unit: UnitDuration.seconds).formatted(.measurement(width: .narrow))).font(.title.monospacedDigit())
            if program.programID == .alcohol { BreatheBanner(icon: "car.fill", title: "alcohol.transport.title", message: "alcohol.transport.detail", tint: .breatheYellow) }
            if program.programID == .gambling { BreatheSecondaryButton(title: "gambling.self_exclusion.action") {} }
            BreatheSecondaryButton(title: "rescue.check_in_now") { stage = 2 }
        }.task { await timer() }
    }

    private func reflection(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            BreatheSectionHeader(title: "rescue.reflect.title", detail: "rescue.reflect.detail")
            BreatheSelectionCard(title: "rescue.outcome.urge_passed", icon: "checkmark.heart", selected: false) { finish(.urgePassed, final: max(1, intensity - 2)) }
            BreatheSelectionCard(title: "rescue.outcome.delayed", icon: "clock", selected: false) { finish(.delayed, final: max(1, intensity - 1)) }
            BreatheSelectionCard(title: "rescue.outcome.behavior_occurred", icon: "heart", selected: false) { finish(.behaviorOccurred, final: intensity) }
            BreatheSelectionCard(title: "rescue.outcome.still_dealing", icon: "ellipsis.circle", selected: false) { finish(.stillDealingWithIt, final: intensity) }
            Text("rescue.helpful.question").font(.headline)
            HStack { BreatheSecondaryButton(title: "Yes") { helpful = true }; BreatheSecondaryButton(title: "No") { helpful = false } }
        }
    }

    private func begin() {
        initialDate = .now
        let candidates = program.programID.definition.strategyIDs
        let observations = environment.recoveryStore.state.strategyObservations
        selectedStrategy = environment.strategyRanking.rank(programID: program.programID, candidates: candidates,
                                                              triggerID: nil, context: nil, observations: observations).first?.id ?? candidates[0]
        stage = 1
    }

    private func finish(_ outcome: EpisodeOutcome, final: Int) {
        environment.recoveryStore.add(UrgeEpisode(programInstanceID: program.id, occurredAt: initialDate,
                                                   intensity: intensity, outcome: outcome))
        environment.recoveryStore.add(StrategyObservation(strategyID: selectedStrategy, programID: program.programID,
                                                            initialIntensity: intensity, finalIntensity: final,
                                                            outcome: outcome, helpful: helpful))
        BreatheFeedback.success(); dismiss()
    }

    private func timer() async { while remaining > 0 && stage == 1 { try? await Task.sleep(for: .seconds(1)); remaining -= 1 }; if remaining == 0 { stage = 2 } }
    private var strategySymbol: String { switch selectedStrategy { case "walk": "figure.walk"; case "contact": "person.2.fill"; case "delay", "delay_deposit", "cooling_off": "timer"; case "leave", "close_app": "door.left.hand.open"; default: "wind" } }
}

struct ProgramUrgesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showRescue = false
    private var program: RecoveryProgram? { environment.recoveryStore.primaryProgram }
    var body: some View { NavigationStack { BreatheScreen { metrics in
        if let program { VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            BreathePrimaryButton(title: "rescue.start", icon: "wind") { showRescue = true }
            let episodes = environment.recoveryStore.state.urges.filter { $0.programInstanceID == program.id }.sorted { $0.occurredAt > $1.occurredAt }
            if episodes.isEmpty { BreatheEmptyState(icon: "waveform.path.ecg", title: "urges.empty.title", message: "urges.empty.detail", actionTitle: "rescue.start", action: { showRescue = true }) }
            else { ForEach(episodes) { episode in BreatheCard { HStack { VStack(alignment: .leading) { Text(outcomeKey(episode.outcome)); Text(episode.occurredAt, style: .relative).foregroundStyle(Color.breatheTextSecondary) }; Spacer(); Text("\(episode.intensity)/5").monospacedDigit() } } } }
        }.padding(.bottom, metrics.majorSpacing) }
    }.navigationTitle("Urges") }.fullScreenCover(isPresented: $showRescue) { if let program { ProgramRescueView(program: program) } } }
    private func outcomeKey(_ outcome: EpisodeOutcome) -> LocalizedStringKey { LocalizedStringKey("rescue.outcome.\(outcome.rawValue)") }
}

struct ProgramProgressView: View {
    @Environment(AppEnvironment.self) private var environment
    private var program: RecoveryProgram? { environment.recoveryStore.primaryProgram }
    var body: some View { NavigationStack { BreatheScreen { metrics in
        if let program { let episodes = environment.recoveryStore.state.urges.filter { $0.programInstanceID == program.id }; let passed = episodes.filter { $0.outcome != .behaviorOccurred }.count
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                BreatheSectionHeader(title: "progress.personal.title", detail: "progress.personal.detail")
                LazyVGrid(columns: metrics.metricColumns) { BreatheMetricCard(icon: "waveform", value: "\(episodes.count)", title: "progress.urges_logged"); BreatheMetricCard(icon: "checkmark.shield", value: "\(passed)", title: "progress.pauses_created", tint: .breatheSky) }
                BreatheBanner(icon: "chart.line.uptrend.xyaxis", title: "insight.confidence.early", message: "insight.early.detail", tint: .breatheYellow)
            }
        }
    }.navigationTitle("Progress") } }
}
