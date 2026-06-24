import SwiftUI
import Charts
import BreatheCore

/// Two charts that turn the raw craving log into patterns: which triggers hit
/// hardest (and how often you beat them), and what time of day is risky.
struct CravingChartsView: View {
    let triggerBreakdown: [TriggerBreakdown]
    let hourly: [HourlyCravings]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            triggerChart
            hourlyChart
        }
        .padding(.vertical, 4)
    }

    // MARK: By trigger (resisted vs gave in, stacked)

    private var triggerChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By trigger")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(triggerBreakdown) { item in
                    BarMark(
                        x: .value("Count", item.resisted),
                        y: .value("Trigger", item.trigger.label)
                    )
                    .foregroundStyle(by: .value("Outcome", String(localized: "Resisted")))

                    BarMark(
                        x: .value("Count", item.gaveIn),
                        y: .value("Trigger", item.trigger.label)
                    )
                    .foregroundStyle(by: .value("Outcome", String(localized: "Gave in")))
                }
            }
            .chartForegroundStyleScale([
                String(localized: "Resisted"): Color.green,
                String(localized: "Gave in"): Color.red.opacity(0.7)
            ])
            .chartLegend(position: .bottom)
            .frame(height: max(120, CGFloat(triggerBreakdown.count) * 44))
        }
    }

    // MARK: By hour of day

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By time of day")
                .font(.subheadline.weight(.semibold))

            Chart(hourly) { item in
                BarMark(
                    x: .value("Hour", item.hour),
                    y: .value("Cravings", item.count)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour)h")
                        }
                    }
                }
            }
            .frame(height: 160)
        }
    }
}

#Preview {
    CravingChartsView(
        triggerBreakdown: [
            TriggerBreakdown(trigger: .stress, total: 5, resisted: 3),
            TriggerBreakdown(trigger: .coffee, total: 3, resisted: 1),
            TriggerBreakdown(trigger: .boredom, total: 2, resisted: 2)
        ],
        hourly: [
            HourlyCravings(hour: 8, count: 2),
            HourlyCravings(hour: 13, count: 4),
            HourlyCravings(hour: 20, count: 3)
        ]
    )
    .padding()
}
