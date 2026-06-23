import Foundation

/// Evaluates the health-recovery timeline against a ``QuitPlan``.
public struct MilestoneEngine: Sendable {
    private let catalogue: [HealthMilestone]

    /// - Parameter catalogue: the milestones to track, defaulting to the
    ///   canonical recovery timeline. Injectable so tests can use a small set.
    public init(catalogue: [HealthMilestone] = HealthMilestone.catalogue) {
        self.catalogue = catalogue.sorted { $0.offset < $1.offset }
    }

    /// The status of every milestone as of `reference`, in timeline order.
    public func statuses(for plan: QuitPlan, at reference: Date) -> [MilestoneStatus] {
        let elapsed = max(0, reference.timeIntervalSince(plan.quitDate))
        return catalogue.map { milestone in
            let achieved = elapsed >= milestone.offset
            let fraction = milestone.offset > 0
                ? min(1, elapsed / milestone.offset)
                : 1
            return MilestoneStatus(
                milestone: milestone,
                isAchieved: achieved,
                fraction: fraction,
                reachedAt: plan.quitDate.addingTimeInterval(milestone.offset)
            )
        }
    }

    /// The next milestone the user has not yet reached, if any remain.
    public func nextMilestone(for plan: QuitPlan, at reference: Date) -> MilestoneStatus? {
        statuses(for: plan, at: reference).first { !$0.isAchieved }
    }

    /// How many milestones have been reached as of `reference`.
    public func achievedCount(for plan: QuitPlan, at reference: Date) -> Int {
        statuses(for: plan, at: reference).filter(\.isAchieved).count
    }
}
