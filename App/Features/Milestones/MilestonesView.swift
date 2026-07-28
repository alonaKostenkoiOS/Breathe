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
            BreatheScreen {
                VStack(alignment: .leading, spacing: BreatheSpacing.lg) {
                    progressHero
                    smokeFreeCalendar
                    BreatheSectionHeader(title: "Health recovery", detail: "A gentle timeline of estimated changes.")
                    timeline
                    BreatheBanner(icon: "info.circle", title: "Recovery is personal",
                                  message: "Health recovery times are estimates and can vary from person to person.", tint: .breatheSky)
                }.padding(.bottom, BreatheSpacing.xl)
            }
            .navigationTitle("Progress")
            .toolbarBackground(Color.breatheBackground, for: .navigationBar)
        }
    }

    private var progressHero: some View {
        let achieved = statuses.filter(\.isAchieved).count
        let fraction = statuses.isEmpty ? 0 : Double(achieved) / Double(statuses.count)
        return BreatheCard(tint: .breatheSurfaceSoft, elevated: true) {
            HStack(spacing: BreatheSpacing.lg) {
                ZStack {
                    Circle().stroke(Color.breatheAccentSoft, lineWidth: 12)
                    Circle().trim(from: 0, to: fraction).stroke(Color.breatheAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack { Text("\(achieved)").font(.breatheMetric); Text("of \(statuses.count)").font(.caption).foregroundStyle(Color.breatheTextSecondary) }
                }.frame(width: 112, height: 112).accessibilityLabel("\(achieved) of \(statuses.count) health milestones reached")
                VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                    Text("Your body is recovering").font(.breatheSectionTitle)
                    Text("Every day without smoking gives your body more room to heal.").font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                }
            }
        }
    }

    private var smokeFreeCalendar: some View {
        VStack(alignment: .leading, spacing: BreatheSpacing.sm) {
            BreatheSectionHeader(title: "Last four weeks", detail: "Your smoke-free days at a glance.")
            BreatheCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: BreatheSpacing.xs) {
                    ForEach(0..<28, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset - 27, to: environment.dateProvider.now()) ?? .now
                        let active = plan.map { date >= Calendar.current.startOfDay(for: $0.quitDate) } ?? false
                        Circle().fill(active ? Color.breatheAccent : .breatheDivider).frame(width: 24, height: 24)
                            .overlay(active ? Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) : nil)
                            .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue(active ? "Smoke-free" : "Before quit date")
                    }
                }
            }
        }
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(statuses.enumerated()), id: \.element.id) { index, status in
                HStack(alignment: .top, spacing: BreatheSpacing.md) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(status.isAchieved ? Color.breatheAccent : .breatheBackgroundSecondary).frame(width: 36, height: 36)
                            Image(systemName: status.isAchieved ? "checkmark" : "leaf").font(.caption.bold())
                                .foregroundStyle(status.isAchieved ? .white : Color.breatheTextTertiary)
                        }
                        if index < statuses.count - 1 { Rectangle().fill(status.isAchieved ? Color.breatheAccentMedium : .breatheDivider).frame(width: 2, height: 78) }
                    }
                    VStack(alignment: .leading, spacing: BreatheSpacing.xs) {
                        Text(status.milestone.title).font(.headline).foregroundStyle(status.isAchieved ? Color.breatheText : .breatheTextSecondary)
                        Text(status.milestone.detail).font(.breatheCallout).foregroundStyle(Color.breatheTextSecondary)
                        if !status.isAchieved { BreatheProgressBar(value: status.fraction) }
                    }.padding(.top, BreatheSpacing.xs)
                    Spacer()
                }.accessibilityElement(children: .combine)
                    .accessibilityValue(status.isAchieved ? "Completed" : "In progress")
            }
        }
    }
}

#Preview { MilestonesView().environment(AppEnvironment.preview()) }
