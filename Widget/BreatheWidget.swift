import WidgetKit
import SwiftUI
import BreatheCore

private let appGroup = "group.com.breathe.app"
private let planKey = "quit_plan"

/// Reads the shared ``QuitPlan`` written by the app.
private func loadPlan() -> QuitPlan? {
    guard
        let defaults = UserDefaults(suiteName: appGroup),
        let data = defaults.data(forKey: planKey)
    else { return nil }
    return try? JSONDecoder().decode(QuitPlan.self, from: data)
}

struct BreatheEntry: TimelineEntry {
    let date: Date
    let progress: BreatheCore.Progress
    let currencyCode: String
    let hasPlan: Bool
}

struct BreatheProvider: TimelineProvider {
    private let calculator = ProgressCalculator()

    func placeholder(in context: Context) -> BreatheEntry {
        BreatheEntry(date: Date(), progress: BreatheCore.Progress.zero, currencyCode: "USD", hasPlan: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BreatheEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreatheEntry>) -> Void) {
        // Refresh hourly — money and cigarettes change slowly enough that a
        // tighter cadence would just burn the widget's refresh budget.
        let now = Date()
        let entries = (0..<6).map { hour in
            entry(for: now.addingTimeInterval(Double(hour) * 3_600))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> BreatheEntry {
        guard let plan = loadPlan() else {
            return BreatheEntry(date: date, progress: BreatheCore.Progress.zero, currencyCode: "USD", hasPlan: false)
        }
        return BreatheEntry(
            date: date,
            progress: calculator.progress(for: plan, at: date),
            currencyCode: plan.currencyCode,
            hasPlan: true
        )
    }
}

struct BreatheWidgetView: View {
    let entry: BreatheEntry
    private let formatter = ProgressFormatter()

    var body: some View {
        if entry.hasPlan {
            VStack(alignment: .leading, spacing: 6) {
                Label("Smoke-free", systemImage: "lungs.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(entry.progress.daysSmokeFree)d")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(formatter.money(entry.progress.moneySaved, currencyCode: entry.currencyCode))
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("\(entry.progress.cigarettesAvoided) not smoked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "lungs")
                Text("Open Breathe to start")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct BreatheWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreatheWidget", provider: BreatheProvider()) { entry in
            BreatheWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Smoke-Free Progress")
        .description("Your days, money saved and cigarettes avoided at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BreatheWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreatheWidget()
    }
}
