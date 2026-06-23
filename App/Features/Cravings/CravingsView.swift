import SwiftUI
import BreatheCore

struct CravingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: CravingsViewModel?
    @State private var isLogging = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Cravings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isLogging = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log a craving")
                }
            }
            .sheet(isPresented: $isLogging) {
                LogCravingView { intensity, trigger, didResist, note in
                    await model?.log(intensity: intensity, trigger: trigger, didResist: didResist, note: note)
                }
            }
        }
        .onAppear {
            if model == nil { model = CravingsViewModel(environment: environment) }
        }
        .task { await model?.load() }
    }

    @ViewBuilder
    private func content(_ model: CravingsViewModel) -> some View {
        List {
            if model.insights.total > 0 {
                Section {
                    InsightsSummary(insights: model.insights)
                }
            }
            Section("History") {
                if model.cravings.isEmpty {
                    ContentUnavailableView(
                        "No cravings logged",
                        systemImage: "checkmark.seal",
                        description: Text("Log a craving when one hits — spotting patterns is half the battle.")
                    )
                } else {
                    ForEach(model.cravings) { craving in
                        CravingRow(craving: craving)
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { model.cravings[$0] }
                        Task { for craving in toDelete { await model.delete(craving) } }
                    }
                }
            }
        }
    }
}

private struct InsightsSummary: View {
    let insights: CravingInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(Int(insights.resistanceRate * 100))% resisted", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                Spacer()
                Text("\(insights.resisted)/\(insights.total)")
                    .foregroundStyle(.secondary)
            }
            if let top = insights.topTrigger {
                Text("Your biggest trigger is **\(top.label.lowercased())**.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CravingRow: View {
    let craving: Craving

    var body: some View {
        HStack {
            Image(systemName: craving.didResist ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(craving.didResist ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(craving.trigger.label)
                    .font(.body)
                Text(craving.date, format: .dateTime.weekday().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(repeating: "🔥", count: craving.intensity))
                .font(.caption)
        }
    }
}

#Preview {
    CravingsView()
        .environment(AppEnvironment.preview())
}
