import Foundation

/// Product events intentionally carry no program identifier, timestamp,
/// trigger, amount, quantity, location, note, screening answer, or contact.
enum RecoveryAnalyticsEvent: String, Sendable {
    case programOnboardingCompleted = "program_onboarding_completed"
    case rescueStarted = "rescue_started"
    case rescueCompleted = "rescue_completed"
    case ifThenPlanCreated = "if_then_plan_created"
    case riskWindowAccepted = "risk_window_accepted"
    case weeklyExperimentCompleted = "weekly_experiment_completed"
}

protocol RecoveryAnalyticsTracking: Sendable { func track(_ event: RecoveryAnalyticsEvent) }
struct NoopRecoveryAnalytics: RecoveryAnalyticsTracking { func track(_ event: RecoveryAnalyticsEvent) {} }
