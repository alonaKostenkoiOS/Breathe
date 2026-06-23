import SwiftUI
import BreatheCore

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: DashboardViewModel?

    private let formatter = ProgressFormatter()

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Smoke-Free")
        }
        .onAppear {
            if model == nil { model = DashboardViewModel(environment: environment) }
        }
        .task {
            await model?.loadFact()
            await model?.startTicking()
        }
    }

    @ViewBuilder
    private func content(_ model: DashboardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                timeHeadline(model)
                statGrid(model)
                if let next = model.nextMilestone {
                    nextMilestoneCard(next)
                }
                if let fact = model.fact {
                    factCard(fact)
                }
            }
            .padding()
        }
    }

    private func timeHeadline(_ model: DashboardViewModel) -> some View {
        VStack(spacing: 4) {
            Text(formatter.duration(model.progress.timeSmokeFree))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("smoke-free")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statGrid(_ model: DashboardViewModel) -> some View {
        let currency = model.plan?.currencyCode ?? "USD"
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "dollarsign.circle.fill",
                value: formatter.money(model.progress.moneySaved, currencyCode: currency),
                caption: "Money saved",
                tint: .green
            )
            StatCard(
                icon: "smoke.fill",
                value: "\(model.progress.cigarettesAvoided)",
                caption: "Not smoked",
                tint: .orange
            )
            StatCard(
                icon: "heart.fill",
                value: formatter.lifeRegained(model.progress.lifeRegained),
                caption: "Life regained",
                tint: .pink
            )
            StatCard(
                icon: "calendar",
                value: "\(model.progress.daysSmokeFree)",
                caption: "Days",
                tint: .blue
            )
        }
    }

    private func nextMilestoneCard(_ status: MilestoneStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next milestone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(status.milestone.title)
                .font(.headline)
            ProgressView(value: status.fraction)
                .tint(.accentColor)
            Text(status.milestone.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func factCard(_ fact: HealthFact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Did you know?", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(fact.text)
                .font(.callout)
            if let source = fact.source {
                Text("— \(source)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DashboardView()
        .environment(AppEnvironment.preview())
}
