import SwiftUI
import BreatheCore

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: DashboardViewModel?
    @State private var showRescue = false
    private let formatter = ProgressFormatter()

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { loading } }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.breatheBackground, for: .navigationBar)
        }
        .tint(.breatheAccent)
        .onAppear { if model == nil { model = DashboardViewModel(environment: environment) } }
        .task { await model?.loadFact(); await model?.startTicking() }
        .fullScreenCover(isPresented: $showRescue) {
            CravingRescueView(personalReason: environment.planStore.profile?.personalReason)
        }
    }

    private var loading: some View {
        BreatheScreen(scrollable: false) { metrics in
            VStack(spacing: metrics.cardPadding) {
                ProgressView().tint(.breatheAccent)
                Text("Preparing your progress…").foregroundStyle(Color.breatheTextSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ model: DashboardViewModel) -> some View {
        BreatheScreen { metrics in
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                smokeFreeHero(model, metrics)
                rescueAction(metrics)
                if let next = model.nextMilestone { milestone(next, metrics) }
                BreatheSectionHeader(title: "What you’ve gained")
                progressMetrics(model, metrics)
                if let reason = environment.planStore.profile?.personalReason, !reason.isEmpty {
                    motivation(reason)
                }
                if let goal = model.goal, let progress = model.goalProgress { goalCard(goal, progress, model, metrics) }
                if let fact = model.fact { factCard(fact) }
            }.padding(.bottom, metrics.majorSpacing)
        }
    }

    private func smokeFreeHero(_ model: DashboardViewModel, _ metrics: AppLayoutMetrics) -> some View {
        BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
            VStack(alignment: .leading, spacing: metrics.cardPadding) {
                HStack {
                    Label("Your smoke-free journey", systemImage: "leaf.fill")
                        .font(AppTypography.callout(for: metrics.mode).weight(.semibold)).foregroundStyle(Color.breatheAccent)
                    Spacer()
                    Text("Day \(max(model.progress.daysSmokeFree, 1))")
                        .font(AppTypography.caption(for: metrics.mode).weight(.semibold)).foregroundStyle(Color.breatheTextSecondary)
                }
                Text(formatter.duration(model.progress.timeSmokeFree))
                    .font(AppTypography.heroTitle(for: metrics.mode)).monospacedDigit().minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                Text("Every smoke-free moment is meaningful.")
                    .font(AppTypography.body(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                if let next = model.nextMilestone {
                    VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                        BreatheProgressBar(value: next.fraction)
                        Text("Moving toward \(next.milestone.title.lowercased())")
                            .font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func rescueAction(_ metrics: AppLayoutMetrics) -> some View {
        Button { BreatheFeedback.selection(); showRescue = true } label: {
            HStack(spacing: metrics.cardPadding) {
                Image(systemName: "wind").font(.title2).frame(width: metrics.buttonHeight - 8, height: metrics.buttonHeight - 8)
                    .background(Color.breatheAccentSoft, in: Circle()).foregroundStyle(Color.breatheAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("I’m having a craving").font(.headline)
                    Text("Take a quiet minute with Breathe").font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.breatheTextTertiary)
            }.padding(metrics.cardPadding)
        }.buttonStyle(.plain).frame(minHeight: 72)
            .background(Color.breatheSurface, in: RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous).stroke(Color.breatheAccentMedium, lineWidth: 1.5))
            .accessibilityLabel("I’m having a craving")
            .accessibilityHint("Opens a guided breathing exercise")
    }

    private func progressMetrics(_ model: DashboardViewModel, _ metrics: AppLayoutMetrics) -> some View {
        let currency = model.plan?.currencyCode ?? "USD"
        return LazyVGrid(columns: metrics.metricColumns, spacing: metrics.internalSpacing) {
            BreatheMetricCard(icon: "leaf.fill", value: "\(model.progress.cigarettesAvoided)", title: "Cigarettes avoided")
            BreatheMetricCard(icon: "banknote.fill", value: formatter.money(model.progress.moneySaved, currencyCode: currency), title: "Money saved", tint: .breatheSky)
            BreatheMetricCard(icon: "heart.fill", value: formatter.lifeRegained(model.progress.lifeRegained), title: "Life regained", tint: .breathePeach)
        }
    }

    private func milestone(_ status: MilestoneStatus, _ metrics: AppLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "Next milestone")
            BreatheCard {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: metrics.internalSpacing) { milestoneContent(status, metrics) }
                    VStack(alignment: .leading, spacing: metrics.internalSpacing) { milestoneContent(status, metrics) }
                }
            }
        }
    }

    @ViewBuilder private func milestoneContent(_ status: MilestoneStatus, _ metrics: AppLayoutMetrics) -> some View {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.breatheAccent)
                    VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                        Text(status.milestone.title).font(.headline)
                        Text(status.milestone.detail).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                        BreatheProgressBar(value: status.fraction)
                    }
    }

    private func motivation(_ reason: String) -> some View {
        BreatheBanner(icon: "quote.opening", title: "Your reason", message: LocalizedStringKey(reason), tint: .breatheYellow)
            .accessibilityLabel("Your reason: \(reason)")
    }

    private func goalCard(_ goal: SavingsGoal, _ progress: GoalProgress, _ model: DashboardViewModel, _ metrics: AppLayoutMetrics) -> some View {
        let currency = model.plan?.currencyCode ?? "USD"
        return VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "Savings goal")
            BreatheCard(tint: .breatheSurfaceSoft) {
                VStack(alignment: .leading, spacing: metrics.internalSpacing) {
                    HStack { Label(goal.name, systemImage: "target").font(.headline); Spacer(); Text("\(Int(progress.fraction * 100))%").monospacedDigit() }
                    BreatheProgressBar(value: progress.fraction)
                    Text(progress.isReached ? "Goal reached — enjoy this moment." : "\(formatter.money(progress.remaining, currencyCode: currency)) to go")
                        .font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func factCard(_ fact: HealthFact) -> some View {
        BreatheBanner(icon: "sun.max.fill", title: "A gentle reminder", message: LocalizedStringKey(fact.text), tint: .breatheSky)
    }
}

#Preview("iPhone SE") {
    DashboardView().environment(AppEnvironment.preview())
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("375-point compact") {
    DashboardView().environment(AppEnvironment.preview()).frame(width: 375, height: 700)
}

#Preview("iPhone Pro Max") {
    DashboardView().environment(AppEnvironment.preview())
        .previewDevice(PreviewDevice(rawValue: "iPhone 17 Pro Max"))
        .preferredColorScheme(.dark)
}

#Preview("iPad expanded") {
    DashboardView().environment(AppEnvironment.preview()).frame(width: 820, height: 1180)
}
