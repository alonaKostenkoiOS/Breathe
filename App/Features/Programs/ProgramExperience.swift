import SwiftUI
import Charts
import BreatheCore

private struct OnboardingDissolveModifier: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    let scale: CGFloat
    let verticalOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale)
            .offset(y: verticalOffset)
    }
}

private extension AnyTransition {
    static var welcomeDissolveOut: AnyTransition {
        .modifier(
            active: OnboardingDissolveModifier(opacity: 0, blur: 18, scale: 1.075, verticalOffset: -12),
            identity: OnboardingDissolveModifier(opacity: 1, blur: 0, scale: 1, verticalOffset: 0)
        )
    }

    static var onboardingRiseIn: AnyTransition {
        .modifier(
            active: OnboardingDissolveModifier(opacity: 0, blur: 14, scale: 0.965, verticalOffset: 34),
            identity: OnboardingDissolveModifier(opacity: 1, blur: 0, scale: 1, verticalOffset: 0)
        )
    }
}

extension RecoveryProgramID {
    var definition: RecoveryProgramDefinition { RecoveryProgramCatalog.definition(self) }
    var nameKey: LocalizedStringKey { LocalizedStringKey(definition.nameKey) }
    var descriptionKey: LocalizedStringKey { LocalizedStringKey(definition.descriptionKey) }
}

private struct FreedomWelcomeScreen: View {
    let metrics: AppLayoutMetrics
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Image("OnboardingHero")
                .resizable()
                .scaledToFill()
                .frame(width: metrics.availableSize.width, height: metrics.availableSize.height)
                .scaleEffect(isBreathing ? 1.045 : 1)
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: Color.breatheBackground.opacity(0.02), location: 0),
                    .init(color: Color.breatheBackground.opacity(0.12), location: 0.42),
                    .init(color: Color.breatheBackground.opacity(0.92), location: 0.68),
                    .init(color: Color.breatheBackground, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .center, spacing: metrics.internalSpacing) {
                    Spacer(minLength: metrics.accessibilityText ? 180 : metrics.availableSize.height * 0.42)

                    Text("onboarding.story.purpose.title")
                        .font(AppTypography.heroTitle(for: metrics.mode))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("onboarding.story.purpose.detail")
                        .font(AppTypography.body(for: metrics.mode))
                        .foregroundStyle(Color.breatheTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, metrics.compactSpacing)

                    BreathePrimaryButton(title: "onboarding.story.start_journey", action: action)

                    Label("Your data stays on your device.", systemImage: "lock.fill")
                        .font(AppTypography.caption(for: metrics.mode))
                        .foregroundStyle(Color.breatheTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, metrics.compactSpacing)
                }
                .padding(.horizontal, metrics.screenPadding)
                .padding(.top, metrics.cardPadding)
                .padding(.bottom, metrics.majorSpacing)
                .frame(minHeight: metrics.availableSize.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("onboarding.platform.hero.accessibility")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct FreedomImpactArtwork: View {
    let metrics: AppLayoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        Image("FreedomImpact")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: metrics.mode == .compact ? 180 : 224)
            .scaleEffect(isFloating ? 1.035 : 1)
            .offset(y: isFloating ? -3 : 3)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            }
            .shadow(color: Color.breatheAccent.opacity(0.12), radius: 18, y: 8)
            .accessibilityLabel("onboarding.story.impact.image.accessibility")
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
    }
}

private struct ScalePeopleArtwork: View {
    let metrics: AppLayoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let highlights: [CGPoint] = [
        .init(x: 0.10, y: 0.62), .init(x: 0.22, y: 0.37),
        .init(x: 0.34, y: 0.68), .init(x: 0.46, y: 0.28),
        .init(x: 0.57, y: 0.60), .init(x: 0.69, y: 0.35),
        .init(x: 0.80, y: 0.66), .init(x: 0.91, y: 0.42)
    ]

    var body: some View {
        let artworkHeight = metrics.accessibilityText ? 72.0 : (metrics.mode == .compact ? 86.0 : 104.0)
        ZStack {
            Image("ScalePeople")
                .resizable()
                .scaledToFit()

            if reduceMotion {
                glowLayer(time: 0, animated: false)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    glowLayer(time: context.date.timeIntervalSinceReferenceDate, animated: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: artworkHeight)
        .accessibilityHidden(true)
    }

    private func glowLayer(time: TimeInterval, animated: Bool) -> some View {
        GeometryReader { proxy in
            ForEach(Array(highlights.enumerated()), id: \.offset) { index, point in
                let wave = animated ? (sin(time * 1.45 - Double(index) * 0.82) + 1) / 2 : 0.38
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.96), Color.breatheSky.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 1,
                            endRadius: 22
                        )
                    )
                    .frame(width: 42, height: 42)
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                    .opacity(0.10 + wave * 0.82)
                    .scaleEffect(0.72 + wave * 0.36)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }
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
    @State private var revealedSupportSteps = 0

    private enum Step: Int, CaseIterable { case welcome, impact, scale, support, selection, checkIn, snapshot }
    private var step: Step { Step(rawValue: min(max(storedStep, 0), Step.allCases.count - 1)) ?? .welcome }
    private var selection: RecoveryProgramID? { RecoveryProgramID(rawValue: storedProgram) }
    private var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }

    var body: some View {
        NavigationStack {
            ZStack {
                if step == .welcome {
                    BreatheScreen(scrollable: false, edgeToEdge: true) { metrics in
                        FreedomWelcomeScreen(metrics: metrics, action: advance)
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .welcomeDissolveOut))
                    .zIndex(1)
                } else {
                    BreatheScreen { metrics in
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            BreatheProgressBar(value: progress)
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
                    .transition(.asymmetric(insertion: .onboardingRiseIn, removal: .opacity))
                    .zIndex(2)
                }
            }
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.9, extraBounce: 0),
                value: step
            )
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
        case .selection: programSelection(metrics)
        case .checkIn: checkIn(metrics)
        case .snapshot: snapshot(metrics)
        }
    }

    private func welcome(_ metrics: AppLayoutMetrics) -> some View { EmptyView() }

    private func impact(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.internalSpacing) {
            Text("onboarding.story.impact.title")
                .font(AppTypography.screenTitle(for: metrics.mode))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("onboarding.story.impact.loses")
                .font(AppTypography.body(for: metrics.mode))
                .foregroundStyle(Color.breatheTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, metrics.compactSpacing)
            LazyVGrid(columns: metrics.metricColumns, spacing: metrics.internalSpacing) {
                lossCard("ImpactSleep", "onboarding.story.impact.sleep", .breatheSky, metrics)
                lossCard("ImpactEnergy", "onboarding.story.impact.focus", .breatheAccentSoft, metrics)
                lossCard("ImpactConnection", "onboarding.story.impact.people", .breathePeach, metrics)
                lossCard("ImpactResources", "onboarding.story.impact.resources", .breatheYellow, metrics)
            }
            Spacer(minLength: metrics.internalSpacing)
            BreathePrimaryButton(title: "onboarding.story.continue", action: advance)
                .padding(.top, metrics.internalSpacing)
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
    }

    private func lossCard(_ image: String, _ title: LocalizedStringKey, _ tint: Color, _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard(tint: tint) {
            VStack(alignment: .leading, spacing: metrics.internalSpacing) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1))
                    .accessibilityHidden(true)
                Spacer(minLength: metrics.compactSpacing)
                Text(title)
                    .font(AppTypography.sectionTitle(for: metrics.mode))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: metrics.mode == .compact ? 118 : 132,
                maxHeight: metrics.mode == .compact ? 118 : 132,
                alignment: .topLeading
            )
        }
    }

    private func scale(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.internalSpacing) {
            Text("onboarding.story.scale.title")
                .font(AppTypography.sectionTitle(for: metrics.mode))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ScalePeopleArtwork(metrics: metrics)
                .padding(.vertical, metrics.compactSpacing)
            statisticsPanel(metrics)
            Spacer(minLength: metrics.internalSpacing)
            Text("onboarding.story.scale.sources_extended").font(AppTypography.caption(for: metrics.mode))
                .foregroundStyle(Color.breatheTextTertiary).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            BreathePrimaryButton(title: "onboarding.story.continue", action: advance)
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
    }

    private func support(_ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.internalSpacing) {
            ZStack {
                Circle()
                    .fill(Color.breatheSky.opacity(0.52))
                    .frame(width: 92, height: 92)
                Circle()
                    .stroke(Color.breatheAccentMedium.opacity(0.25), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: "wind")
                    .font(.system(size: metrics.mode == .compact ? 28 : 32, weight: .medium))
                    .foregroundStyle(Color.breatheAccent)
            }
            .accessibilityHidden(true)
            .padding(.bottom, metrics.compactSpacing)
            VStack(spacing: metrics.compactSpacing) {
                Text("onboarding.story.rescue.title")
                    .font(AppTypography.screenTitle(for: metrics.mode)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("onboarding.story.rescue.detail")
                    .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, metrics.internalSpacing)

            VStack(spacing: metrics.compactSpacing) {
                stagedSupportRow(1, "bolt.heart.fill", "onboarding.story.rescue.urge", false, metrics)
                supportConnector(visible: revealedSupportSteps >= 2)
                stagedSupportRow(2, "pause.fill", "onboarding.story.rescue.pause", true, metrics)
                supportConnector(visible: revealedSupportSteps >= 3)
                stagedSupportRow(3, "arrow.forward", "onboarding.story.rescue.next", false, metrics)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: metrics.internalSpacing) {
                Label("onboarding.story.rescue.offline", systemImage: "wifi.slash")
                Label("onboarding.story.rescue.private", systemImage: "lock.fill")
            }
            .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary)
            .frame(maxWidth: .infinity)
            Text("onboarding.story.rescue.disclaimer").font(.caption2)
                .foregroundStyle(Color.breatheTextTertiary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: metrics.internalSpacing)
            BreathePrimaryButton(title: "onboarding.story.rescue.action", action: advance)
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
        .task {
            revealedSupportSteps = reduceMotion ? 3 : 0
            guard !reduceMotion else { return }
            for stage in 1...3 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(stage == 1 ? 180 : 320))
                withAnimation(.smooth(duration: 0.48, extraBounce: 0.05)) {
                    revealedSupportSteps = stage
                }
            }
        }
    }

    private func programSelection(_ metrics: AppLayoutMetrics) -> some View {
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
            Spacer(minLength: metrics.internalSpacing)
            BreathePrimaryButton(title: "program.selection.continue", disabled: selection == nil, action: advance)
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
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
            Spacer(minLength: metrics.internalSpacing)
            BreathePrimaryButton(title: "onboarding.checkin.show", disabled: frequency == 0 || difficultPeriod < 0, action: advance)
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
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
            Spacer(minLength: metrics.internalSpacing)
            BreathePrimaryButton(title: "onboarding.snapshot.action", disabled: selection == nil) {
                guard let selection else { return }
                platformOnboardingCompleted = true
                _ = environment.recoveryStore.start(selection)
                storedStep = 0; storedProgram = ""; frequency = 0; intensity = 3; difficultPeriod = -1
            }
        }
        .frame(minHeight: onboardingPageHeight(metrics), alignment: .top)
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

    private func statisticCard(_ value: String, _ detail: LocalizedStringKey,
                               _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.compactSpacing) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.breatheText)

            Text(detail)
                .font(AppTypography.caption(for: metrics.mode))
                .foregroundStyle(Color.breatheTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(metrics.mode == .compact ? 12 : 14)
        .frame(
            maxWidth: .infinity,
            minHeight: metrics.mode == .compact ? 88 : 96,
            maxHeight: metrics.mode == .compact ? 88 : 96,
            alignment: .topLeading
        )
        .background {
            LinearGradient(
                colors: [Color.breatheSurface.opacity(0.98), Color.breatheSky.opacity(0.44)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func statisticsPanel(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.compactSpacing) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: metrics.compactSpacing), GridItem(.flexible())],
                spacing: metrics.compactSpacing
            ) {
                statisticCard("750M+", "onboarding.story.scale.tobacco_short", metrics)
                statisticCard("400M", "onboarding.story.scale.alcohol_short", metrics)
                statisticCard("1/4", "onboarding.story.scale.digital_short", metrics)
                statisticCard("1/20", "onboarding.story.scale.spending_short", metrics)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                statisticCard("448M", "onboarding.story.scale.gambling_short", metrics)
                    .frame(maxWidth: (metrics.availableSize.width - metrics.screenPadding * 2 - metrics.compactSpacing) / 2)
                Spacer(minLength: 0)
            }
        }
        .shadow(color: Color.breatheAccent.opacity(0.05), radius: 10, y: 4)
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

    private func stagedSupportRow(_ stage: Int, _ icon: String, _ title: LocalizedStringKey,
                                  _ highlighted: Bool, _ metrics: AppLayoutMetrics) -> some View {
        HStack(spacing: metrics.internalSpacing) {
            ZStack {
                Circle()
                    .fill(highlighted ? Color.breatheAccent : Color.breatheSurface)
                Text("\(stage)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(highlighted ? Color.white : Color.breatheAccent)
            }
            .frame(width: 38, height: 38)

            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.breatheAccent)
                .frame(width: 26)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.callout(for: metrics.mode).weight(highlighted ? .semibold : .regular))
                .foregroundStyle(Color.breatheText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.cardPadding)
        .padding(.vertical, metrics.internalSpacing)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background {
            LinearGradient(
                colors: highlighted
                    ? [Color.breatheSky.opacity(0.86), Color.breatheAccentSoft.opacity(0.68)]
                    : [Color.breatheSurface.opacity(0.96), Color.breatheSky.opacity(0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.controlRadius, style: .continuous)
                .stroke(highlighted ? Color.breatheAccentMedium.opacity(0.38) : Color.white.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.breatheAccent.opacity(highlighted ? 0.08 : 0.035), radius: 10, y: 4)
        .opacity(revealedSupportSteps >= stage ? 1 : 0)
        .scaleEffect(revealedSupportSteps >= stage ? 1 : 0.96)
        .offset(y: revealedSupportSteps >= stage ? 0 : 14)
        .accessibilityElement(children: .combine)
    }

    private func supportConnector(visible: Bool) -> some View {
        Capsule()
            .fill(Color.breatheAccentMedium.opacity(0.42))
            .frame(width: 2, height: 12)
            .opacity(visible ? 1 : 0)
            .scaleEffect(y: visible ? 1 : 0, anchor: .top)
            .accessibilityHidden(true)
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
    private func onboardingPageHeight(_ metrics: AppLayoutMetrics) -> CGFloat {
        // The progress bar lives above the page content. Reserve only its real
        // footprint so the page fills the viewport and its primary action rests
        // against the lower safe-area padding on every device height.
        max(560, metrics.availableSize.height - (metrics.mode == .compact ? 64 : 72))
    }

    private func advance() {
        direction = 1
        let next = min(step.rawValue + 1, Step.allCases.count - 1)
        if reduceMotion { storedStep = next }
        else {
            let animation: Animation = step == .welcome
                ? .smooth(duration: 0.9, extraBounce: 0)
                : .easeInOut(duration: 0.52)
            withAnimation(animation) { storedStep = next }
        }
    }

    private func back() {
        direction = -1
        let previous = max(step.rawValue - 1, 0)
        if reduceMotion { storedStep = previous }
        else {
            let animation: Animation = step == .impact
                ? .smooth(duration: 0.82, extraBounce: 0)
                : .easeInOut(duration: 0.52)
            withAnimation(animation) { storedStep = previous }
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
