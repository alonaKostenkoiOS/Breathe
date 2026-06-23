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
}
