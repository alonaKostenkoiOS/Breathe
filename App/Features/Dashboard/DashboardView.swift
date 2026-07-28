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
        BreatheScreen(scrollable: false) {
            VStack(spacing: BreatheSpacing.md) {
                ProgressView().tint(.breatheAccent)
                Text("Preparing your progress…").foregroundStyle(Color.breatheTextSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ model: DashboardViewModel) -> some View {
        BreatheScreen {
            VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
                smokeFreeHero(model)
                rescueAction
                BreatheSectionHeader(title: "What you’ve gained")
                metrics(model)
                if let next = model.nextMilestone { milestone(next) }
                if let reason = environment.planStore.profile?.personalReason, !reason.isEmpty {
                    motivation(reason)
                }
                if let goal = model.goal, let progress = model.goalProgress { goalCard(goal, progress, model) }
                if let fact = model.fact { factCard(fact) }
            }.padding(.bottom, BreatheSpacing.xl)
        }
    }

    private func smokeFreeHero(_ model: DashboardViewModel) -> some View {
        BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
            VStack(alignment: .leading, spacing: BreatheSpacing.md) {
                HStack {
                    Label("Your smoke-free journey", systemImage: "leaf.fill")
                        .font(.breatheCallout.weight(.semibold)).foregroundStyle(Color.breatheAccent)
                    Spacer()
                    Text("Day \(max(model.progress.daysSmokeFree, 1))")
                        .font(.breatheCaption.weight(.semibold)).foregroundStyle(Color.breatheTextSecondary)
                }
                Text(formatter.duration(model.progress.timeSmokeFree))
                    .font(.breatheLargeTitle).monospacedDigit().minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                Text("Every smoke-free moment is meaningful.")
                    .font(.breatheBody).foregroundStyle(Color.breatheTextSecondary)
                if let next = model.nextMilestone {
                    VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                        BreatheProgressBar(value: next.fraction)
                        Text("Moving toward \(next.milestone.title.lowercased())")
                            .font(.breatheCaption).foregroundStyle(Color.breatheTextSecondary)
                    }
                }
            }
        }
    }

    private var rescueAction: some View {
        Button { BreatheFeedback.selection(); showRescue = true } label: {
            HStack(spacing: BreatheSpacing.md) {
                Image(systemName: "wind").font(.title2).frame(width: 48, height: 48)
                    .background(Color.breatheAccentSoft, in: Circle()).foregroundStyle(Color.breatheAccent)
                VStack(alignment: .leading, spacing: BreatheSpacing.xxs) {
                    Text("I’m having a craving").font(.headline)
                    Text("Take a quiet minute with Breathe").font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.breatheTextTertiary)
            }.padding(BreatheSpacing.md)
        }.buttonStyle(.plain).frame(minHeight: 72)
            .background(Color.breatheSurface, in: RoundedRectangle(cornerRadius: BreatheRadius.card))
            .overlay(RoundedRectangle(cornerRadius: BreatheRadius.card).stroke(Color.breatheAccentMedium, lineWidth: 1.5))
            .accessibilityLabel("I’m having a craving")
            .accessibilityHint("Opens a guided breathing exercise")
    }

    private func metrics(_ model: DashboardViewModel) -> some View {
        let currency = model.plan?.currencyCode ?? "USD"
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BreatheSpacing.sm) {
            BreatheMetricCard(icon: "leaf.fill", value: "\(model.progress.cigarettesAvoided)", title: "Cigarettes avoided")
            BreatheMetricCard(icon: "banknote.fill", value: formatter.money(model.progress.moneySaved, currencyCode: currency), title: "Money saved", tint: .breatheSky)
            BreatheMetricCard(icon: "heart.fill", value: formatter.lifeRegained(model.progress.lifeRegained), title: "Life regained", tint: .breathePeach)
        }
    }

    private func milestone(_ status: MilestoneStatus) -> some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "Next milestone")
            BreatheCard {
                HStack(alignment: .top, spacing: BreatheSpacing.sm) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.breatheAccent)
                    VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                        Text(status.milestone.title).font(.headline)
                        Text(status.milestone.detail).font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                        BreatheProgressBar(value: status.fraction)
                    }
                }
            }
        }
    }

    private func motivation(_ reason: String) -> some View {
        BreatheBanner(icon: "quote.opening", title: "Your reason", message: LocalizedStringKey(reason), tint: .breatheYellow)
            .accessibilityLabel("Your reason: \(reason)")
    }

    private func goalCard(_ goal: SavingsGoal, _ progress: GoalProgress, _ model: DashboardViewModel) -> some View {
        let currency = model.plan?.currencyCode ?? "USD"
        return VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "Savings goal")
            BreatheCard(tint: .breatheSurfaceSoft) {
                VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
                    HStack { Label(goal.name, systemImage: "target").font(.headline); Spacer(); Text("\(Int(progress.fraction * 100))%").monospacedDigit() }
                    BreatheProgressBar(value: progress.fraction)
                    Text(progress.isReached ? "Goal reached — enjoy this moment." : "\(formatter.money(progress.remaining, currencyCode: currency)) to go")
                        .font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                }
            }
        }
    }

    private func factCard(_ fact: HealthFact) -> some View {
        BreatheBanner(icon: "sun.max.fill", title: "A gentle reminder", message: LocalizedStringKey(fact.text), tint: .breatheSky)
    }
}

#Preview { DashboardView().environment(AppEnvironment.preview()) }
