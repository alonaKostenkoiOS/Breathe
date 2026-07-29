import WidgetKit
import SwiftUI
import BreatheCore

// MARK: - Timeline

struct FactEntry: TimelineEntry {
    let date: Date
    let fact: HealthFact
}

/// Self-contained provider: it surfaces a daily recovery fact from the
/// bundled catalogue, so the widget works on any account without needing an
/// App Group. (A personalised stats widget that reads the app's data is
/// possible too, but that requires the App Group capability — see README.)
struct FactProvider: TimelineProvider {
    private let facts = HealthFact.fallback
    private let calendar = Calendar(identifier: .gregorian)

    func placeholder(in context: Context) -> FactEntry {
        FactEntry(date: Date(), fact: facts[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (FactEntry) -> Void) {
        completion(FactEntry(date: Date(), fact: fact(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FactEntry>) -> Void) {
        // One entry per day for the next week; the fact rotates each day.
        let startOfToday = calendar.startOfDay(for: Date())
        let entries = (0..<7).compactMap { offset -> FactEntry? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { return nil }
            return FactEntry(date: day, fact: fact(for: day))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Deterministic per-day selection so the same day always shows the same
    /// fact and consecutive days rotate through the catalogue.
    private func fact(for day: Date) -> HealthFact {
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        return facts[abs(dayNumber) % facts.count]
    }
}

// MARK: - View

struct BreatheWidgetView: View {
    let entry: FactEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let metrics = WidgetLayoutMetrics(family: family)
        VStack(alignment: .leading, spacing: metrics.spacing) {
            Label("A moment for you", systemImage: "leaf.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 0.05, green: 0.35, blue: 0.26))

            Text(entry.fact.text)
                .font(metrics.factFont)
                .fontWeight(.medium)
                .minimumScaleFactor(0.8)
                .lineLimit(metrics.lineLimit)

            if family != .systemSmall, let source = entry.fact.source {
                Spacer(minLength: 0)
                Text("— \(source)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetLayoutMetrics {
    let family: WidgetFamily

    var spacing: CGFloat { family == .systemSmall ? 6 : 10 }
    var factFont: Font {
        switch family {
        case .systemSmall: .caption
        case .systemMedium: .callout
        case .systemLarge: .body
        default: .caption
        }
    }
    var lineLimit: Int {
        switch family {
        case .systemSmall: 5
        case .systemMedium: 4
        case .systemLarge: 8
        default: 3
        }
    }
}

// MARK: - Widget

struct BreatheWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreatheWidget", provider: FactProvider()) { entry in
            BreatheWidgetView(entry: entry)
                .containerBackground(Color(red: 0.96, green: 0.97, blue: 0.95), for: .widget)
        }
        .configurationDisplayName("Daily Motivation")
        .description("A daily reminder of how your body recovers while you stay smoke-free.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct BreatheWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreatheWidget()
    }
}
