import Foundation
import BreatheCore

/// Privacy-safe product signals for the Coach. Intensity, trigger, personal
/// reason, notes, and timestamps are deliberately excluded.
enum CoachAnalyticsEvent: Sendable, Equatable {
    case started(entryPoint: CoachEntryPoint)
    case recommendationShown(strategy: CoachStrategyID)
    case strategyStarted(strategy: CoachStrategyID)
    case completed(outcome: CoachOutcome, strategy: CoachStrategyID?)
    case abandoned
}

protocol CoachAnalyticsTracking: Sendable {
    func track(_ event: CoachAnalyticsEvent)
}

struct NoopCoachAnalytics: CoachAnalyticsTracking {
    func track(_ event: CoachAnalyticsEvent) {}
}
