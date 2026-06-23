import SwiftUI
import Charts
import BreatheCore

struct MilestonesView: View {
    @Environment(AppEnvironment.self) private var environment

    private var statuses: [MilestoneStatus] {
        guard let plan = environment.planStore.plan else { return [] }
        return environment.milestoneEngine.statuses(for: plan, at: environment.dateProvider.now())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    recoveryChart
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }
                Section("Timeline") {
                    ForEach(statuses) { status in
                        MilestoneRow(status: status)
                    }
                }
            }
            .navigationTitle("Recovery")
        }
    }

    /// Overall recovery as the share of milestones reached.
    private var recoveryChart: some View {
        let achieved = statuses.filter(\.isAchieved).count
        let total = max(statuses.count, 1)
        return Chart {
            SectorMark(
                angle: .value("Reached", achieved),
                innerRadius: .ratio(0.66),
                angularInset: 1.5
            )
            .foregroundStyle(Color.accentColor)
            SectorMark(
                angle: .value("Remaining", total - achieved),
                innerRadius: .ratio(0.66),
                angularInset: 1.5
            )
            .foregroundStyle(Color.gray.opacity(0.2))
        }
        .chartBackground { _ in
            VStack {
                Text("\(achieved)/\(total)")
                    .font(.title.bold())
                Text("milestones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MilestoneRow: View {
    let status: MilestoneStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.isAchieved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(status.isAchieved ? Color.accentColor : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(status.milestone.title)
                    .font(.headline)
                    .foregroundStyle(status.isAchieved ? .primary : .secondary)
                Text(status.milestone.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !status.isAchieved {
                    ProgressView(value: status.fraction)
                        .tint(.accentColor)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.milestone.title), \(status.isAchieved ? "reached" : "in progress")")
    }
}

#Preview {
    MilestonesView()
        .environment(AppEnvironment.preview())
}
