import Foundation

enum OnboardingAnalyticsEvent: Sendable, Equatable {
    case started
    case stepViewed(step: Int)
    case stepCompleted(step: Int)
    case skipped(step: Int)
    case notificationPermissionRequested
    case notificationPermissionResult(granted: Bool)
    case completed
}

protocol OnboardingAnalyticsTracking: Sendable {
    func track(_ event: OnboardingAnalyticsEvent)
}

/// Deliberately local/no-op. This seam can later forward non-sensitive event
/// names to an analytics implementation without changing onboarding UI.
struct NoopOnboardingAnalytics: OnboardingAnalyticsTracking {
    func track(_ event: OnboardingAnalyticsEvent) {}
}
