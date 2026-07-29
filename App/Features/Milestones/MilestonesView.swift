import SwiftUI
import BreatheCore

struct MilestonesView: View {
    @Environment(AppEnvironment.self) private var environment
    private var plan: QuitPlan? { environment.planStore.plan }
    private var statuses: [MilestoneStatus] {
        guard let plan else { return [] }
        return environment.milestoneEngine.statuses(for: plan, at: environment.dateProvider.now())
    }

    var body: some View {
        NavigationStack {
            BreatheScreen { metrics in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    progressHero(metrics)
                    smokeFreeCalendar(metrics)
                    BreatheSectionHeader(title: "Health recovery", detail: "A gentle timeline of estimated changes.")
                    timeline(metrics)
                    BreatheBanner(icon: "info.circle", title: "Recovery is personal",
                                  message: "Health recovery times are estimates and can vary from person to person.", tint: .breatheSky)
                }.padding(.bottom, metrics.majorSpacing)
            }
            .navigationTitle("Progress")
            .toolbarBackground(Color.breatheBackground, for: .navigationBar)
        }
    }

    private func progressHero(_ metrics: AppLayoutMetrics) -> some View {
        let achieved = statuses.filter(\.isAchieved).count
        let fraction = statuses.isEmpty ? 0 : Double(achieved) / Double(statuses.count)
        return BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: metrics.sectionSpacing) { progressHeroContent(achieved, fraction, metrics) }
                VStack(alignment: .leading, spacing: metrics.internalSpacing) { progressHeroContent(achieved, fraction, metrics) }
            }
        }
    }

    @ViewBuilder private func progressHeroContent(_ achieved: Int, _ fraction: Double, _ metrics: AppLayoutMetrics) -> some View {
                ZStack {
                    Circle().stroke(Color.breatheAccentSoft, lineWidth: metrics.mode == .compact ? 9 : 11)
                    Circle().trim(from: 0, to: fraction).stroke(Color.breatheAccent, style: StrokeStyle(lineWidth: metrics.mode == .compact ? 9 : 11, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack { Text("\(achieved)").font(AppTypography.metric(for: metrics.mode)); Text("of \(statuses.count)").font(AppTypography.caption(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary) }
                }.frame(width: metrics.mode == .compact ? 94 : 108, height: metrics.mode == .compact ? 94 : 108).accessibilityLabel("\(achieved) of \(statuses.count) health milestones reached")
                VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                    Text("Your body is recovering").font(AppTypography.sectionTitle(for: metrics.mode)).fixedSize(horizontal: false, vertical: true)
                    Text("Every day without smoking gives your body more room to heal.").font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
    }

    private func smokeFreeCalendar(_ metrics: AppLayoutMetrics) -> some View {
        let daySize = min(26, max(18, (metrics.availableSize.width - metrics.screenPadding * 2 - metrics.cardPadding * 2 - 48) / 7))
        return VStack(alignment: .leading, spacing: metrics.internalSpacing) {
            BreatheSectionHeader(title: "Last four weeks", detail: "Your smoke-free days at a glance.")
            BreatheCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: metrics.compactSpacing) {
                    ForEach(0..<28, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset - 27, to: environment.dateProvider.now()) ?? .now
                        let active = plan.map { date >= Calendar.current.startOfDay(for: $0.quitDate) } ?? false
                        Circle().fill(active ? Color.breatheAccent : .breatheDivider).frame(width: daySize, height: daySize)
                            .overlay(active ? Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) : nil)
                            .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue(active ? "Smoke-free" : "Before quit date")
                    }
                }
            }
        }
    }

    private func timeline(_ metrics: AppLayoutMetrics) -> some View {
        VStack(spacing: metrics.internalSpacing) {
            ForEach(statuses) { status in
                HStack(alignment: .top, spacing: metrics.cardPadding) {
                    VStack {
                        ZStack {
                            Circle().fill(status.isAchieved ? Color.breatheAccent : .breatheBackgroundSecondary).frame(width: 34, height: 34)
                            Image(systemName: status.isAchieved ? "checkmark" : "leaf").font(.caption.bold())
                                .foregroundStyle(status.isAchieved ? .white : Color.breatheTextTertiary)
                        }
                    }
                    VStack(alignment: .leading, spacing: metrics.compactSpacing) {
                        Text(status.milestone.title).font(.headline).foregroundStyle(status.isAchieved ? Color.breatheText : .breatheTextSecondary)
                        Text(status.milestone.detail).font(AppTypography.callout(for: metrics.mode)).foregroundStyle(Color.breatheTextSecondary).fixedSize(horizontal: false, vertical: true)
                        if !status.isAchieved { BreatheProgressBar(value: status.fraction) }
                    }.padding(.top, metrics.compactSpacing)
                    Spacer()
                }.accessibilityElement(children: .combine)
                    .accessibilityValue(status.isAchieved ? "Completed" : "In progress")
            }
        }
    }
}

#Preview { MilestonesView().environment(AppEnvironment.preview()) }
