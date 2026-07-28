import Foundation
import BreatheCore

/// Persists the single ``QuitPlan`` (and an optional ``SavingsGoal``) to a
/// shared App Group container so both the app and the widget read the same
/// source of truth. Backed by `UserDefaults` because these are small values,
/// not collections.
@MainActor
@Observable
final class PlanStore {
    nonisolated static let appGroup = "group.com.breathe.app"
    private static let planKey = "quit_plan"
    private static let goalKey = "savings_goal"
    private static let profileKey = "quit_profile_v1"
    private static let draftKey = "onboarding_draft_v1"

    private let defaults: UserDefaults
    private(set) var plan: QuitPlan?
    private(set) var goal: SavingsGoal?
    private(set) var profile: QuitProfile?
    private(set) var onboardingDraft: OnboardingDraft?

    init(defaults: UserDefaults = UserDefaults(suiteName: PlanStore.appGroup) ?? .standard) {
        self.defaults = defaults
        self.plan = Self.decode(QuitPlan.self, forKey: Self.planKey, from: defaults)
        self.goal = Self.decode(SavingsGoal.self, forKey: Self.goalKey, from: defaults)
        self.profile = Self.decode(QuitProfile.self, forKey: Self.profileKey, from: defaults)
        self.onboardingDraft = Self.decode(OnboardingDraft.self, forKey: Self.draftKey, from: defaults)

        // A plan written by any previous app version is a completed onboarding.
        // Build a conservative profile without rewriting/removing legacy keys.
        if profile == nil, let plan {
            let migrated = QuitProfile(
                quitDate: plan.quitDate,
                cigarettesPerDay: plan.cigarettesPerDay,
                cigarettesPerPack: plan.cigarettesPerPack,
                packPrice: plan.pricePerPack,
                currencyCode: plan.currencyCode,
                onboardingCompletedAt: Date()
            )
            profile = migrated
            Self.encode(migrated, forKey: Self.profileKey, to: defaults)
        }
    }

    var hasPlan: Bool { plan != nil }
    var isOnboardingComplete: Bool { profile?.onboardingCompletedAt != nil || plan != nil }

    func save(_ plan: QuitPlan) {
        self.plan = plan
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: Self.planKey)
        }
        if var profile {
            profile.quitDate = plan.quitDate
            profile.cigarettesPerDay = plan.cigarettesPerDay
            profile.cigarettesPerPack = plan.cigarettesPerPack
            profile.packPrice = plan.pricePerPack
            profile.currencyCode = plan.currencyCode
            self.profile = profile
            Self.encode(profile, forKey: Self.profileKey, to: defaults)
        }
    }

    func saveGoal(_ goal: SavingsGoal?) {
        self.goal = goal
        if let goal, let data = try? JSONEncoder().encode(goal) {
            defaults.set(data, forKey: Self.goalKey)
        } else {
            defaults.removeObject(forKey: Self.goalKey)
        }
        if var profile {
            profile.savingsGoal = goal
            self.profile = profile
            Self.encode(profile, forKey: Self.profileKey, to: defaults)
        }
    }

    func saveDraft(_ draft: OnboardingDraft) {
        onboardingDraft = draft
        Self.encode(draft, forKey: Self.draftKey, to: defaults)
    }

    func completeOnboarding(with profile: QuitProfile, at date: Date = .now) {
        var completed = profile
        completed.onboardingCompletedAt = date
        self.profile = completed
        save(completed.quitPlan)
        saveGoal(completed.savingsGoal)
        Self.encode(completed, forKey: Self.profileKey, to: defaults)
        onboardingDraft = nil
        defaults.removeObject(forKey: Self.draftKey)
    }

    func reset() {
        plan = nil
        goal = nil
        defaults.removeObject(forKey: Self.planKey)
        defaults.removeObject(forKey: Self.goalKey)
        profile = nil
        onboardingDraft = nil
        defaults.removeObject(forKey: Self.profileKey)
        defaults.removeObject(forKey: Self.draftKey)
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }


    private static func encode<T: Encodable>(_ value: T, forKey key: String, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
