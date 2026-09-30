import SwiftUI
import Charts
import BreatheCore

extension RecoveryProgramID {
    var definition: RecoveryProgramDefinition { RecoveryProgramCatalog.definition(self) }
    var nameKey: LocalizedStringKey { LocalizedStringKey(definition.nameKey) }
    var descriptionKey: LocalizedStringKey { LocalizedStringKey(definition.descriptionKey) }
}

struct ProgramSelectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("platform_onboarding_story_step_v2") private var storedStep = 0
    @AppStorage("platform_onboarding_program") private var storedProgram = ""
    @AppStorage("platform_onboarding_completed") private var platformOnboardingCompleted = false
    @AppStorage("platform_onboarding_frequency") private var frequency = 0
    @AppStorage("platform_onboarding_intensity") private var intensity = 3
    @AppStorage("platform_onboarding_period") private var difficultPeriod = -1
    @State private var direction = 1

    private enum Step: Int, CaseIterable { case welcome, impact, scale, support, selection, checkIn, snapshot }
    private var step: Step { Step(rawValue: min(max(storedStep, 0), Step.allCases.count - 1)) ?? .welcome }
    private var selection: RecoveryProgramID? { RecoveryProgramID(rawValue: storedProgram) }
    private var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    if step != .welcome { BreatheProgressBar(value: progress) }
                    content(metrics)
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                .padding(.bottom, metrics.majorSpacing)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: step)
            }
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        BreatheIconButton(icon: "chevron.left", label: "Back", action: back)
                    }
                }
            }
        }
    }

    @ViewBuilder private func content(_ metrics: AppLayoutMetrics) -> some View {
        switch step {
        case .welcome: welcome(metrics)
        case .impact: impact(metrics)
        case .scale: scale(metrics)
        case .support: support(metrics)
        case .selection: programSelection
        case .checkIn: checkIn(metrics)
        case .snapshot: snapshot(metrics)
        }
    }

    private func welcome(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            if metrics.heroImageHeight > 0 {
                Image("OnboardingHero")
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: metrics.heroImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Label("Breathe", systemImage: "leaf.fill")
                            .font(.headline).foregroundStyle(Color.breatheAccent)
                            .padding(.horizontal, metrics.internalSpacing).frame(minHeight: 44)
                            .background(.ultraThinMaterial, in: Capsule()).padding(metrics.internalSpacing)
                    }
                    .accessibilityLabel("onboarding.platform.hero.accessibility")
            }
            platformTitle("onboarding.story.purpose.title", "onboarding.story.purpose.detail", metrics)
            BreathePrimaryButton(title: "onboarding.story.continue", action: advance)
            Label("Your data stays on your device.", systemImage: "lock.fill")
                .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
        }
    }

    private func impact(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            platformTitle("onboarding.story.impact.title", "onboarding.story.impact.detail", metrics)
            LazyVGrid(columns: metrics.metricColumns, spacing: metrics.internalSpacing) {
                impactCard("heart.text.square.fill", "onboarding.story.impact.health", .breathePeach, metrics)
                impactCard("brain.head.profile", "onboarding.story.impact.attention", .breatheSky, metrics)
                impactCard("person.2.fill", "onboarding.story.impact.relationships", .breatheAccentSoft, metrics)
                impactCard("banknote.fill", "onboarding.story.impact.money", .breatheYellow, metrics)
            }
            Text("onboarding.story.impact.qualifier").font(AppTypography.caption(for: metrics.mode))
                .foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
            BreathePrimaryButton(title: "onboarding.story.continue", action: advance)
        }
    }

    private func scale(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.sectionSpacing) {
            VStack(spacing: metrics.compactSpacing) {
                Text("onboarding.story.scale.title")
                    .font(AppTypography.screenTitle(for: metrics.mode))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("onboarding.story.scale.detail")
                    .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity)
            statistic("750M+", "onboarding.story.scale.tobacco", .breatheAccentSoft, metrics)
            statistic("400M", "onboarding.story.scale.alcohol", .breatheSky, metrics)
            statistic("×6", "onboarding.story.scale.gambling", .breatheYellow, metrics)
            Text("onboarding.story.scale.source").font(AppTypography.caption(for: metrics.mode))
                .foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            BreathePrimaryButton(title: "onboarding.story.continue", action: advance)
        }
    }

    private func support(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.sectionSpacing) {
            Image(systemName: "wind")
                .font(.system(size: metrics.mode == .compact ? 30 : 36, weight: .semibold))
                .foregroundStyle(Color.breatheAccent)
                .frame(width: 72, height: 72)
                .background(Color.breatheAccentSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: metrics.compactSpacing) {
                Text("onboarding.story.rescue.title")
                    .font(AppTypography.screenTitle(for: metrics.mode)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("onboarding.story.rescue.detail")
                    .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
                VStack(spacing: metrics.internalSpacing) {
                    rescueJourneyRow("bolt.heart.fill", "onboarding.story.rescue.urge", false, metrics)
                    Image(systemName: "arrow.down").foregroundStyle(Color.breatheAccentMedium).accessibilityHidden(true)
                    rescueJourneyRow("pause.fill", "onboarding.story.rescue.pause", true, metrics)
                    Image(systemName: "arrow.down").foregroundStyle(Color.breatheAccentMedium).accessibilityHidden(true)
                    rescueJourneyRow("arrow.forward.circle.fill", "onboarding.story.rescue.next", false, metrics)
                }
            }
            HStack(spacing: metrics.internalSpacing) {
                Label("onboarding.story.rescue.offline", systemImage: "wifi.slash")
                Label("onboarding.story.rescue.private", systemImage: "lock.fill")
            }
            .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
            .frame(maxWidth: .infinity)
            BreathePrimaryButton(title: "onboarding.story.rescue.action", action: advance)
            Text("onboarding.story.rescue.disclaimer").font(.caption2)
                .foregroundStyle(Color.breatheTextTertiary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var programSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BreatheSectionHeader(title: "program.selection.title", detail: "program.selection.detail")
            ForEach(RecoveryProgramID.allCases) { id in
                let definition = id.definition
                BreatheSelectionCard(title: id.nameKey, detail: id.descriptionKey,
                                     icon: definition.iconName, selected: selection == id) {
                    storedProgram = id.rawValue
                    BreatheFeedback.selection()
                }
            }
            BreathePrimaryButton(title: "program.selection.continue", disabled: selection == nil, action: advance)
        }
    }

    private func checkIn(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            platformTitle("onboarding.checkin.title", "onboarding.checkin.detail", metrics)
            question("onboarding.checkin.frequency") {
                HStack(spacing: metrics.compactSpacing) {
                    ForEach(1...4, id: \.self) { value in
                        answerChip(frequencyKey(value), selected: frequency == value) { frequency = value }
                    }
                }
            }
            question("onboarding.checkin.intensity") {
                HStack(spacing: metrics.compactSpacing) {
                    ForEach(1...5, id: \.self) { value in
                        Button("\(value)") { intensity = value; BreatheFeedback.selection() }
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                            .background(intensity == value ? Color.breatheAccentSoft : .breatheSurface,
                                        in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)
                                .stroke(intensity == value ? Color.breatheAccent : .breatheDivider,
                                        lineWidth: intensity == value ? 2 : 1))
                            .foregroundStyle(Color.breatheText)
                    }
                }
            }
            question("onboarding.checkin.period") {
                HStack(spacing: metrics.compactSpacing) {
                    ForEach(0...3, id: \.self) { value in
                        answerChip(periodKey(value), selected: difficultPeriod == value) { difficultPeriod = value }
                    }
                }
            }
            BreathePrimaryButton(title: "onboarding.checkin.show", disabled: frequency == 0 || difficultPeriod < 0, action: advance)
        }
    }

    private func snapshot(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            platformTitle("onboarding.snapshot.title", "onboarding.snapshot.detail", metrics)
            BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
                VStack(alignment: .leading, spacing: metrics.internalSpacing) {
                    Chart(snapshotPoints) { point in
                        AreaMark(x: .value("Time", point.hour), y: .value("Intensity", point.value))
                            .foregroundStyle(LinearGradient(colors: [.breatheAccentMedium.opacity(0.5), .breatheAccentSoft.opacity(0.08)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", point.hour), y: .value("Intensity", point.value))
                            .foregroundStyle(Color.breatheAccent).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...5.5).chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: [8, 14, 20]) { value in
                            AxisValueLabel {
                                if let hour = value.as(Int.self) { Text(axisKey(hour)).font(.caption) }
                            }
                        }
                    }
                    .frame(height: metrics.chartHeight)
                    .accessibilityLabel("onboarding.snapshot.chart.accessibility")
                    HStack(spacing: metrics.compactSpacing) {
                        Image(systemName: "circle.fill").font(.caption2).foregroundStyle(Color.breatheAccent)
                        Text(snapshotInsight).font(AppTypography.callout(for: metrics.mode))
                            .foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("onboarding.snapshot.disclaimer")
                .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            BreathePrimaryButton(title: "onboarding.snapshot.action", disabled: selection == nil) {
                guard let selection else { return }
                platformOnboardingCompleted = true
                _ = environment.recoveryStore.start(selection)
                storedStep = 0; storedProgram = ""; frequency = 0; intensity = 3; difficultPeriod = -1
            }
        }
    }

    private func platformTitle(_ title: LocalizedStringKey, _ detail: LocalizedStringKey,
                               _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.compactSpacing) {
            Text(title).font(AppTypography.heroTitle(for: metrics.mode))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(detail).font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func question<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.headline); content() }
    }

    private func impactCard(_ icon: String, _ title: LocalizedStringKey, _ tint: Color,
                            _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard(tint: tint) {
            VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.breatheAccent)
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statistic(_ value: String, _ detail: LocalizedStringKey, _ tint: Color,
                           _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard(tint: tint) {
            VStack(spacing: metrics.compactSpacing) {
                Text(value).font(AppTypography.metric(for: metrics.mode)).monospacedDigit().foregroundStyle(Color.breatheAccent)
                Text(detail).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity)
        }
    }

    private func rescueJourneyRow(_ icon: String, _ title: LocalizedStringKey, _ highlighted: Bool,
                                  _ metrics: AppLayoutMetrics) -> some View {
        Label(title, systemImage: icon)
            .font(highlighted ? .headline : AppTypography.body(for: metrics.mode))
            .foregroundStyle(highlighted ? Color.breatheAccent : Color.breatheText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(highlighted ? Color.breatheAccentSoft : .clear,
                        in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private func answerChip(_ title: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); BreatheFeedback.selection() } label: {
            Text(title).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 4)
        }.buttonStyle(.plain)
            .background(selected ? Color.breatheAccentSoft : .breatheSurface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Color.breatheAccent : .breatheDivider, lineWidth: selected ? 2 : 1))
    }

    private struct SnapshotPoint: Identifiable { let hour: Int; let value: Double; var id: Int { hour } }
    private var snapshotPoints: [SnapshotPoint] {
        let peakHour = [9, 14, 20, 15][max(0, min(difficultPeriod, 3))]
        let base = Double(frequency) * 0.35
        return stride(from: 6, through: 24, by: 3).map { hour in
            let distance = Double(abs(hour - peakHour))
            let peak = Double(intensity) * exp(-(distance * distance) / 24)
            return SnapshotPoint(hour: hour, value: min(5, max(0.25, base + peak)))
        }
    }
    private var snapshotInsight: LocalizedStringKey { LocalizedStringKey("onboarding.snapshot.insight." + periodID) }
    private var periodID: String { ["morning", "day", "evening", "varies"][max(0, min(difficultPeriod, 3))] }
    private func frequencyKey(_ value: Int) -> LocalizedStringKey { LocalizedStringKey("onboarding.checkin.frequency." + ["", "rare", "weekly", "daily", "often"][value]) }
    private func periodKey(_ value: Int) -> LocalizedStringKey { LocalizedStringKey("onboarding.checkin.period." + ["morning", "day", "evening", "varies"][value]) }
    private func axisKey(_ hour: Int) -> LocalizedStringKey { hour == 8 ? "onboarding.chart.morning" : hour == 14 ? "onboarding.chart.day" : "onboarding.chart.evening" }

    private func advance() { direction = 1; storedStep = min(step.rawValue + 1, Step.allCases.count - 1) }
    private func back() { direction = -1; storedStep = max(step.rawValue - 1, 0) }
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
