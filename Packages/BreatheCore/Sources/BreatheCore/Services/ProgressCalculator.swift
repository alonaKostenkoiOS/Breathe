import Foundation

/// Turns a ``QuitPlan`` into a ``Progress`` snapshot for a given instant.
///
/// The calculator is a pure, stateless value type: same inputs always
/// produce the same output, which makes it trivial to unit test.
public struct ProgressCalculator: Sendable {
    public init() {}

    /// Computes progress for `plan` as of `reference`.
    ///
    /// Cigarettes are accrued continuously (a half day smoke-free counts as
    /// half a day's cigarettes) and then floored to a whole count, because a
    /// fractional avoided cigarette is meaningless to show.
    public func progress(for plan: QuitPlan, at reference: Date) -> Progress {
        let elapsed = max(0, reference.timeIntervalSince(plan.quitDate))
        let days = elapsed / 86_400
        let avoided = Int((days * Double(plan.cigarettesPerDay)).rounded(.down))

        let moneySaved = plan.pricePerCigarette * Decimal(avoided)
        let lifeRegained = Double(avoided) * plan.minutesOfLifePerCigarette * 60

        return Progress(
            timeSmokeFree: elapsed,
            cigarettesAvoided: avoided,
            moneySaved: moneySaved,
            lifeRegained: lifeRegained
        )
    }
}
