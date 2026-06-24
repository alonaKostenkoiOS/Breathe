import Foundation

/// A savings target the user is working toward ("a new phone", "a trip").
public struct SavingsGoal: Sendable, Hashable, Codable {
    public var name: String
    public var target: Decimal

    public init(name: String, target: Decimal) {
        self.name = name
        self.target = target
    }
}

/// The user's progress toward a ``SavingsGoal`` at a point in time.
public struct GoalProgress: Sendable, Hashable {
    /// 0...1 share of the target reached.
    public let fraction: Double
    /// Amount still to save (0 once reached).
    public let remaining: Decimal
    public let isReached: Bool
    /// Projected date the goal is reached, or `nil` if already reached or the
    /// savings rate is zero.
    public let eta: Date?

    public init(fraction: Double, remaining: Decimal, isReached: Bool, eta: Date?) {
        self.fraction = fraction
        self.remaining = remaining
        self.isReached = isReached
        self.eta = eta
    }
}

/// Computes progress toward a savings goal from the money already saved and
/// the user's daily savings rate. Pure and deterministic.
public struct SavingsGoalCalculator: Sendable {
    private let progressCalculator: ProgressCalculator

    public init(progressCalculator: ProgressCalculator = .init()) {
        self.progressCalculator = progressCalculator
    }

    public func progress(goal: SavingsGoal, plan: QuitPlan, at reference: Date) -> GoalProgress {
        let saved = progressCalculator.progress(for: plan, at: reference).moneySaved
        let target = max(goal.target, 0)

        guard target > 0 else {
            return GoalProgress(fraction: 1, remaining: 0, isReached: true, eta: nil)
        }

        let fraction = min(1, double(saved) / double(target))
        let remaining = max(target - saved, 0)
        let isReached = saved >= target

        var eta: Date?
        let dailyRate = plan.pricePerCigarette * Decimal(plan.cigarettesPerDay)
        if !isReached, dailyRate > 0 {
            let daysNeeded = double(remaining) / double(dailyRate)
            eta = reference.addingTimeInterval(daysNeeded * 86_400)
        }

        return GoalProgress(fraction: fraction, remaining: remaining, isReached: isReached, eta: eta)
    }

    private func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
