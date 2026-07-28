import Foundation
import Testing
@testable import BreatheCore

@Suite("Onboarding support")
struct OnboardingSupportTests {
    @Test func onboardingInputFeedsUnchangedProgressCalculation() {
        let quitDate = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = QuitProfile(quitDate: quitDate, cigarettesPerDay: 20,
                                  cigarettesPerPack: 20, packPrice: 10, currencyCode: "USD")
        let progress = ProgressCalculator().progress(for: profile.quitPlan,
                                                      at: quitDate.addingTimeInterval(7 * 86_400))
        #expect(progress.cigarettesAvoided == 140)
        #expect(progress.moneySaved == 70)
    }

    @Test func validatesDateAndNumericBounds() {
        let now = Date(timeIntervalSince1970: 100)
        #expect(OnboardingValidation.isValidQuitDate(now, now: now))
        #expect(!OnboardingValidation.isValidQuitDate(now.addingTimeInterval(1), now: now))
        #expect(OnboardingValidation.isValidCount(20, range: 1...80))
        #expect(!OnboardingValidation.isValidCount(0, range: 1...80))
        #expect(OnboardingValidation.isValidPrice(12.50))
        #expect(!OnboardingValidation.isValidPrice(0))
    }

    @Test func currencyFallbackSupportsUkraine() {
        #expect(CurrencyResolver.currencyCode(for: Locale(identifier: "uk_UA")) == "UAH")
        #expect(CurrencyResolver.currencyCode(for: Locale(identifier: "en_US")) == "USD")
    }

    @Test func conditionalNavigationSkipsQuitDateForToday() {
        #expect(OnboardingStep.status.next(status: .quittingToday) == .routine)
        #expect(OnboardingStep.status.next(status: .alreadyQuit) == .quitDate)
        #expect(OnboardingStep.routine.previous(status: .quittingToday) == .status)
    }

    @Test func draftAndRoutineEventsRoundTrip() throws {
        let event = RoutineEvent(type: .morningCoffee, localHour: 7, localMinute: 35)
        let profile = QuitProfile(quitDate: .distantPast, cigarettesPerDay: 10,
                                  packPrice: 8, currencyCode: "EUR", routineEvents: [event])
        let draft = OnboardingDraft(step: OnboardingStep.routineTiming.rawValue,
                                    journeyStatus: .alreadyQuit, profile: profile)
        let restored = try JSONDecoder().decode(OnboardingDraft.self,
                                                from: JSONEncoder().encode(draft))
        #expect(restored == draft)
        #expect(restored.profile.routineEvents.first?.localHour == 7)
        #expect(restored.profile.routineEvents.first?.localMinute == 35)
    }

    @Test func riskFoundationUsesEarlyDayBands() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = QuitProfile(quitDate: now.addingTimeInterval(-2 * 86_400),
                                  cigarettesPerDay: 10, packPrice: 8, currencyCode: "USD")
        #expect(InitialRiskContext(profile: profile, now: now).baseline == .highest)
    }

    @Test func notificationDenialStillFinishesOnboarding() {
        #expect(NotificationPermissionFlow.nextStep(granted: false) == .summary)
        #expect(NotificationPermissionFlow.nextStep(granted: true) == .summary)
    }
}
