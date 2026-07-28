import Foundation

public enum OnboardingValidation {
    public static func isValidQuitDate(_ date: Date, now: Date) -> Bool { date <= now }
    public static func isValidCount(_ value: Int, range: ClosedRange<Int>) -> Bool { range.contains(value) }
    public static func isValidPrice(_ value: Decimal) -> Bool { value > 0 && value <= 100_000 }
    public static func trimmedReason(_ value: String) -> String? {
        let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150))
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum CurrencyResolver {
    public static func currencyCode(for locale: Locale) -> String {
        if let code = locale.currency?.identifier, code.count == 3 { return code }
        if locale.language.languageCode?.identifier == "uk" || locale.region?.identifier == "UA" { return "UAH" }
        return "USD"
    }
}

public enum OnboardingStep: Int, Codable, Sendable, CaseIterable {
    case welcome, status, quitDate, routine, firstCigarette, triggers, routineTiming
    case motivation, savingsGoal, smartSupport, notifications, summary

    public func next(status: JourneyStatus?) -> OnboardingStep? {
        if self == .status, status == .quittingToday { return .routine }
        return OnboardingStep(rawValue: rawValue + 1)
    }

    public func previous(status: JourneyStatus?) -> OnboardingStep? {
        if self == .routine, status == .quittingToday { return .status }
        return OnboardingStep(rawValue: rawValue - 1)
    }
}

public enum NotificationPermissionFlow {
    /// Permission is optional; both outcomes continue to the plan summary.
    public static func nextStep(granted: Bool) -> OnboardingStep { .summary }
}

/// The stable inputs a future rule engine can consume without coupling it to UI.
public struct InitialRiskContext: Sendable, Equatable {
    public enum Baseline: Sendable { case highest, elevated, standard }
    public let baseline: Baseline
    public let triggers: Set<SmokingTrigger>
    public let routineEvents: [RoutineEvent]
    public let firstCigaretteTiming: FirstCigaretteTiming

    public init(profile: QuitProfile, now: Date) {
        let days = max(0, Calendar.current.dateComponents([.day], from: profile.quitDate, to: now).day ?? 0)
        baseline = days < 3 ? .highest : (days < 7 ? .elevated : .standard)
        triggers = profile.triggers
        routineEvents = profile.routineEvents.filter(\.isEnabled)
        firstCigaretteTiming = profile.firstCigaretteTiming
    }
}
