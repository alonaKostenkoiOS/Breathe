import SwiftUI
import BreatheCore

struct CravingRescueView: View {
    let personalReason: String?
    var entryPoint: CoachEntryPoint = .home
    var initialIntensity: Int?
    var initialTrigger: Craving.Trigger?
    var onCompleted: (() async -> Void)?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .checkIn
    @State private var intensity = 3
    @State private var trigger: Craving.Trigger?
    @State private var recommendation: CoachRecommendation?
    @State private var strategy: CoachStrategyID?
    @State private var session: CoachSession?
    @State private var remaining = 60
    @State private var expanding = false
    @State private var saving = false
    @State private var didTrackStart = false

    private enum Stage { case checkIn, strategy, exercise, result }

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    header(metrics)
                    switch stage {
                    case .checkIn: checkIn(metrics)
                    case .strategy: strategyPicker(metrics)
                    case .exercise: exercise(metrics)
                    case .result: result(metrics)
                    }
                }.padding(.bottom, metrics.majorSpacing)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(stage == .exercise)
        .onAppear {
            intensity = initialIntensity ?? 3
            trigger = initialTrigger
            if !didTrackStart {
                didTrackStart = true
                environment.coachAnalytics.track(.started(entryPoint: entryPoint))
            }
        }
    }

    private func header(_ metrics: AppLayoutMetrics) -> some View {
        HStack {
            BreatheIconButton(icon: "xmark", label: "Close coach", action: close)
            Spacer()
            Text("Craving Coach").font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
    }

    private func checkIn(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            BreatheSectionHeader(title: "Let’s get through this moment", detail: "A quick check-in helps Breathe choose support that fits.")
            BreatheSectionHeader(title: "How strong is the craving?")
            HStack(spacing: metrics.compactSpacing) {
                ForEach(1...5, id: \.self) { value in
                    Button { intensity = value; BreatheFeedback.selection() } label: {
                        VStack(spacing: 4) {
                            Text("\(value)").font(.headline)
                            Text(LocalizedStringKey(coachIntensityLabel(value))).font(AppTypography.caption(for: metrics.mode)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
                    }
                    .buttonStyle(.plain)
                    .background(intensity == value ? Color.breatheAccentSoft : .breatheSurface,
                                in: RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)
                        .stroke(intensity == value ? Color.breatheAccent : .breatheDivider, lineWidth: intensity == value ? 2 : 1))
                    .accessibilityLabel("Intensity \(value)")
                    .accessibilityAddTraits(intensity == value ? .isSelected : [])
                }
            }
            BreatheSectionHeader(title: "What brought it on?", detail: "Choose the closest match, or continue if you’re not sure.")
            BreatheFlowLayout(spacing: metrics.compactSpacing) {
                ForEach(Craving.Trigger.allCases, id: \.self) { value in
                    BreatheChip(title: LocalizedStringKey(value.label), icon: value.symbol, selected: trigger == value) {
                        trigger = trigger == value ? nil : value
                        BreatheFeedback.selection()
                    }
                }
            }
            BreathePrimaryButton(title: "Find support", icon: "sparkles", action: prepareRecommendation)
        }
    }

    private func strategyPicker(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            BreatheSectionHeader(title: "Try this first", detail: recommendationReason)
            if let recommendation {
                strategyCard(recommendation.primary, recommended: true)
                BreatheSectionHeader(title: "Other options")
                ForEach(recommendation.alternatives) { item in strategyCard(item, recommended: false) }
            }
            BreatheSecondaryButton(title: "Change my answers") { withAnimation { stage = .checkIn } }
        }
    }

    private func strategyCard(_ item: CoachStrategyID, recommended: Bool) -> some View {
        Button { begin(item) } label: {
            BreatheCard(tint: recommended ? .breatheAccentSoft : .breatheSurface) {
                HStack(spacing: 14) {
                    Image(systemName: item.symbol).font(.title2).foregroundStyle(Color.breatheAccent).frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(item.title)).font(.headline)
                        Text(LocalizedStringKey(item.summary)).font(.subheadline).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.breatheTextTertiary)
                }
            }
        }.buttonStyle(.plain)
    }

    private func exercise(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            if strategy == .calmBreathing {
                ZStack {
                    Circle().fill(Color.breatheAccentSoft).frame(width: metrics.breathingDiameter, height: metrics.breathingDiameter)
                        .scaleEffect(reduceMotion ? 1 : (expanding ? 1 : 0.68))
                    VStack(spacing: metrics.compactSpacing) {
                        Text(expanding ? "Breathe in" : "Breathe out").font(AppTypography.sectionTitle(for: metrics.mode))
                        countdown
                    }
                }.animation(reduceMotion ? nil : .easeInOut(duration: 4), value: expanding)
            } else {
                Image(systemName: strategy?.symbol ?? "leaf.fill")
                    .font(.system(size: metrics.mode == .compact ? 48 : 58)).foregroundStyle(Color.breatheAccent)
                Text(LocalizedStringKey(strategy?.title ?? "Stay with this moment"))
                    .font(AppTypography.heroTitle(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                countdown
            }
            if let strategy {
                BreatheCard(tint: .breatheSurfaceSoft) {
                    Text(LocalizedStringKey(strategy.instruction)).font(AppTypography.body(for: metrics.mode))
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let personalReason, !personalReason.isEmpty {
                BreatheBanner(icon: "heart.fill", title: "Remember why you started", message: LocalizedStringKey(personalReason), tint: .breatheYellow)
            }
            BreatheSecondaryButton(title: "Check in now") { withAnimation { stage = .result } }
        }
        .frame(maxWidth: .infinity)
        .task(id: strategy) { await runTimer() }
    }

    private var countdown: some View {
        Text(Measurement(value: Double(remaining), unit: UnitDuration.seconds).formatted(.measurement(width: .narrow).locale(locale)))
            .font(.title.monospacedDigit().weight(.semibold))
    }

    private func result(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            Image(systemName: "leaf.circle.fill").font(.system(size: metrics.mode == .compact ? 48 : 58)).foregroundStyle(Color.breatheAccent)
            Text("How are you feeling now?").font(AppTypography.heroTitle(for: metrics.mode)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("Whatever the answer, taking this pause mattered.").font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).multilineTextAlignment(.center)
            resultButton("It feels easier", outcome: .improved, finalIntensity: max(1, intensity - 2), icon: "arrow.down.heart.fill")
            resultButton("It feels the same", outcome: .unchanged, finalIntensity: intensity, icon: "equal.circle")
            resultButton("It feels stronger", outcome: .worsened, finalIntensity: min(5, intensity + 1), icon: "arrow.up.circle")
            resultButton("I smoked", outcome: .slipped, finalIntensity: intensity, icon: "heart.circle")
            BreatheSecondaryButton(title: "Try another strategy") {
                remaining = 60
                withAnimation { stage = .strategy }
            }
        }.disabled(saving)
    }

    private func resultButton(_ title: LocalizedStringKey, outcome: CoachOutcome, finalIntensity: Int, icon: String) -> some View {
        BreatheSelectionCard(title: title, icon: icon, selected: false) { complete(outcome, finalIntensity: finalIntensity) }
    }

    private var recommendationReason: LocalizedStringKey {
        guard let recommendation else { return "We’re starting with a simple technique." }
        switch recommendation.reason {
        case .gettingStarted: return "We’re starting with a simple technique."
        case .triggerMatch: return "This matches the situation you selected."
        case .previouslyHelpful: return "This helped you before."
        }
    }

    private func prepareRecommendation() {
        Task {
            let history = (try? await environment.coachSessionStore.all()) ?? []
            let recommendation = environment.coachRecommender.recommendation(trigger: trigger, history: history)
            self.recommendation = recommendation
            environment.coachAnalytics.track(.recommendationShown(strategy: recommendation.primary))
            self.session = CoachSession(startedAt: environment.dateProvider.now(), entryPoint: entryPoint,
                                        trigger: trigger, initialIntensity: intensity,
                                        recommendedStrategyID: recommendation.primary)
            withAnimation { stage = .strategy }
        }
    }

    private func begin(_ item: CoachStrategyID) {
        strategy = item
        environment.coachAnalytics.track(.strategyStarted(strategy: item))
        session?.selectedStrategyID = item
        remaining = item == .rideTheWave ? 180 : 60
        withAnimation { stage = .exercise }
    }

    private func complete(_ outcome: CoachOutcome, finalIntensity: Int) {
        guard !saving else { return }
        saving = true
        Task {
            var completed = session ?? CoachSession(startedAt: environment.dateProvider.now(), entryPoint: entryPoint,
                                                    trigger: trigger, initialIntensity: intensity)
            let craving = Craving(date: completed.startedAt, intensity: intensity, trigger: trigger ?? .other,
                                  didResist: outcome != .slipped)
            try? await environment.cravingStore.add(craving)
            completed.completedAt = environment.dateProvider.now()
            completed.finalIntensity = finalIntensity
            completed.outcome = outcome
            completed.cravingID = craving.id
            try? await environment.coachSessionStore.save(completed)
            environment.coachAnalytics.track(.completed(outcome: outcome, strategy: completed.selectedStrategyID))
            await onCompleted?()
            if outcome == .slipped { BreatheFeedback.selection() } else { BreatheFeedback.success() }
            dismiss()
        }
    }

    private func close() {
        if var session {
            session.completedAt = environment.dateProvider.now()
            session.outcome = .abandoned
            environment.coachAnalytics.track(.abandoned)
            Task { try? await environment.coachSessionStore.save(session) }
        }
        dismiss()
    }

    private func runTimer() async {
        while !Task.isCancelled && stage == .exercise && remaining > 0 {
            expanding.toggle()
            try? await Task.sleep(for: .seconds(strategy == .calmBreathing ? 4 : 1))
            remaining = max(0, remaining - (strategy == .calmBreathing ? 4 : 1))
        }
        if remaining == 0, stage == .exercise { withAnimation { stage = .result }; BreatheFeedback.success() }
    }
}

private func coachIntensityLabel(_ value: Int) -> String {
    switch value { case 1: "Mild"; case 2: "Noticeable"; case 3: "Strong"; case 4: "Very strong"; default: "Overwhelming" }
}

private extension CoachStrategyID {
    var title: String { switch self { case .rideTheWave: "Ride the wave"; case .calmBreathing: "Calm breathing"; case .fiveSenses: "Five senses"; case .changeScene: "Change the scene"; case .handsAndMouth: "Keep hands and mouth busy"; case .rememberWhy: "Remember your reason" } }
    var summary: String { switch self { case .rideTheWave: "Give the urge time to rise and pass."; case .calmBreathing: "Slow your breathing for one minute."; case .fiveSenses: "Reconnect with what is around you."; case .changeScene: "Break the familiar routine with movement."; case .handsAndMouth: "Use a simple smoke-free replacement."; case .rememberWhy: "Reconnect with what matters to you." } }
    var instruction: String { switch self { case .rideTheWave: "Notice the urge without fighting it. It can rise, peak, and pass. Stay here until the timer ends."; case .calmBreathing: "Follow the circle. Breathe in gently as it grows, then breathe out as it becomes smaller."; case .fiveSenses: "Name five things you see, four you can feel, three you hear, two you smell, and one you taste."; case .changeScene: "Stand up and move somewhere different. If you can, walk for a minute and take a sip of water."; case .handsAndMouth: "Hold a pen, glass, or small object. Try water, gum, or a crunchy snack if one is nearby."; case .rememberWhy: "Read your reason slowly. Imagine the next choice that keeps you moving toward it." } }
    var symbol: String { switch self { case .rideTheWave: "water.waves"; case .calmBreathing: "wind"; case .fiveSenses: "hand.raised.fingers.spread"; case .changeScene: "figure.walk"; case .handsAndMouth: "hands.sparkles"; case .rememberWhy: "heart.fill" } }
}

#Preview("Coach") {
    CravingRescueView(personalReason: "More energy for my family")
        .environment(AppEnvironment.preview())
}
