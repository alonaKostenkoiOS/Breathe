import Foundation

/// Derives aggregate ``CravingInsights`` from a list of logged cravings.
public struct CravingAnalyzer: Sendable {
    public init() {}

    public func insights(from cravings: [Craving]) -> CravingInsights {
        guard !cravings.isEmpty else { return .empty }

        let resisted = cravings.filter(\.didResist).count
        let resistanceRate = Double(resisted) / Double(cravings.count)

        // Tally triggers; ties resolve to the trigger seen first in the
        // catalogue order so the result is deterministic.
        let counts = Dictionary(grouping: cravings, by: \.trigger).mapValues(\.count)
        let topTrigger = Craving.Trigger.allCases
            .filter { counts[$0] != nil }
            .max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }

        return CravingInsights(
            total: cravings.count,
            resisted: resisted,
            resistanceRate: resistanceRate,
            topTrigger: topTrigger
        )
    }

    /// Cravings grouped by trigger, in the catalogue's canonical order, with
    /// empty triggers omitted. Drives the "by trigger" chart.
    public func breakdownByTrigger(_ cravings: [Craving]) -> [TriggerBreakdown] {
        Craving.Trigger.allCases.compactMap { trigger in
            let matching = cravings.filter { $0.trigger == trigger }
            guard !matching.isEmpty else { return nil }
            return TriggerBreakdown(
                trigger: trigger,
                total: matching.count,
                resisted: matching.filter(\.didResist).count
            )
        }
    }

    /// Cravings bucketed by hour of day (0...23), sorted by hour, with empty
    /// hours omitted. Drives the "time of day" chart.
    public func cravingsByHour(
        _ cravings: [Craving],
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> [HourlyCravings] {
        var buckets: [Int: Int] = [:]
        for craving in cravings {
            let hour = calendar.component(.hour, from: craving.date)
            buckets[hour, default: 0] += 1
        }
        return buckets.keys.sorted().map { HourlyCravings(hour: $0, count: buckets[$0] ?? 0) }
    }
}
