import Foundation
import Testing
import BreatheCore
@testable import Breathe

@MainActor
@Suite("PlanStore onboarding persistence")
struct PlanStoreTests {
    private func defaults() -> UserDefaults {
        let suite = "PlanStoreTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func savesAndRestoresPartialDraft() {
        let defaults = defaults()
        let profile = QuitProfile(quitDate: .now, cigarettesPerDay: 12,
                                  packPrice: 11, currencyCode: "UAH")
        PlanStore(defaults: defaults).saveDraft(OnboardingDraft(step: 6, profile: profile))
        let restored = PlanStore(defaults: defaults)
        #expect(restored.onboardingDraft?.step == 6)
        #expect(!restored.isOnboardingComplete)
    }

    @Test func legacyPlanMigratesAndRoutesToApp() {
        let defaults = defaults()
        let old = PlanStore(defaults: defaults)
        old.save(QuitPlan(quitDate: .distantPast, cigarettesPerDay: 15,
                          pricePerPack: 10, currencyCode: "EUR"))
        let migrated = PlanStore(defaults: defaults)
        #expect(migrated.isOnboardingComplete)
        #expect(migrated.profile?.cigarettesPerDay == 15)
    }

    @Test func completionAtomicallyCreatesPlanAndClearsDraft() {
        let defaults = defaults()
        let store = PlanStore(defaults: defaults)
        let profile = QuitProfile(quitDate: .now, cigarettesPerDay: 10,
                                  packPrice: 9, currencyCode: "USD")
        store.saveDraft(OnboardingDraft(step: 4, profile: profile))
        store.completeOnboarding(with: profile)
        #expect(store.plan != nil)
        #expect(store.profile?.onboardingCompletedAt != nil)
        #expect(store.onboardingDraft == nil)
        #expect(PlanStore(defaults: defaults).isOnboardingComplete)
    }
}
