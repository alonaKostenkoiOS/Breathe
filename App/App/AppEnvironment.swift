import Foundation
import SwiftData
import BreatheCore

/// Composition root. Wires concrete implementations to the protocols the
/// feature layer depends on, and is the single place that knows how the app
/// is assembled. Injected into the SwiftUI environment so views never
/// construct their own dependencies.
@MainActor
@Observable
final class AppEnvironment {
    let planStore: PlanStore
    let recoveryStore: RecoveryProgramStore
    let cravingStore: any CravingStoring
    let coachSessionStore: any CoachSessionStoring
    let coachRecommender: CoachRecommendationService
    let factProvider: any HealthFactProviding
    let notificationService: any NotificationScheduling
    let calculator: ProgressCalculator
    let milestoneEngine: MilestoneEngine
    let goalCalculator: SavingsGoalCalculator
    let analyzer: CravingAnalyzer
    let dateProvider: any DateProviding
    let onboardingAnalytics: any OnboardingAnalyticsTracking
    let coachAnalytics: any CoachAnalyticsTracking
    let safetyService: ProgramSafetyService
    let strategyRanking: PersonalStrategyRankingService
    let riskWindowSuggestions: RiskWindowSuggestionService

    init(
        planStore: PlanStore,
        recoveryStore: RecoveryProgramStore,
        cravingStore: any CravingStoring,
        coachSessionStore: any CoachSessionStoring = LocalCoachSessionStore(),
        coachRecommender: CoachRecommendationService = .init(),
        factProvider: any HealthFactProviding,
        notificationService: any NotificationScheduling = LocalNotificationService(),
        calculator: ProgressCalculator = .init(),
        milestoneEngine: MilestoneEngine = .init(),
        goalCalculator: SavingsGoalCalculator = .init(),
        analyzer: CravingAnalyzer = .init(),
        dateProvider: any DateProviding = SystemDateProvider(),
        onboardingAnalytics: any OnboardingAnalyticsTracking = NoopOnboardingAnalytics(),
        coachAnalytics: any CoachAnalyticsTracking = NoopCoachAnalytics(),
        safetyService: ProgramSafetyService = .init(),
        strategyRanking: PersonalStrategyRankingService = .init(),
        riskWindowSuggestions: RiskWindowSuggestionService = .init()
    ) {
        self.planStore = planStore
        self.recoveryStore = recoveryStore
        self.cravingStore = cravingStore
        self.coachSessionStore = coachSessionStore
        self.coachRecommender = coachRecommender
        self.factProvider = factProvider
        self.notificationService = notificationService
        self.calculator = calculator
        self.milestoneEngine = milestoneEngine
        self.goalCalculator = goalCalculator
        self.analyzer = analyzer
        self.dateProvider = dateProvider
        self.onboardingAnalytics = onboardingAnalytics
        self.coachAnalytics = coachAnalytics
        self.safetyService = safetyService
        self.strategyRanking = strategyRanking
        self.riskWindowSuggestions = riskWindowSuggestions
    }

    /// The live environment used by the running app.
    static func live() -> AppEnvironment {
        let container = SharedContainer.make()
        let factsURL = URL(string: "https://raw.githubusercontent.com/breathe-app/facts/main/facts.json")!

        let planStore = PlanStore()
        return AppEnvironment(
            planStore: planStore,
            recoveryStore: RecoveryProgramStore(hasLegacyNicotineData: planStore.isOnboardingComplete),
            cravingStore: SwiftDataCravingStore(modelContainer: container),
            factProvider: RemoteHealthFactProvider(endpoint: factsURL, fetcher: URLSession.shared)
        )
    }

    /// A fully in-memory environment for SwiftUI previews and UI tests.
    static func preview() -> AppEnvironment {
        let store = PlanStore(defaults: UserDefaults(suiteName: "preview")!)
        store.save(QuitPlan(
            quitDate: Date().addingTimeInterval(-86_400 * 9),
            cigarettesPerDay: 15,
            pricePerPack: 12,
            currencyCode: "USD"
        ))
        store.saveGoal(SavingsGoal(name: "Weekend trip", target: 300))
        return AppEnvironment(
            planStore: store,
            recoveryStore: RecoveryProgramStore(defaults: UserDefaults(suiteName: "preview.recovery")!, hasLegacyNicotineData: true),
            cravingStore: InMemoryCravingStore([
                Craving(date: .now.addingTimeInterval(-3_600), intensity: 4, trigger: .stress, didResist: true),
                Craving(date: .now.addingTimeInterval(-50_000), intensity: 5, trigger: .stress, didResist: false),
                Craving(date: .now.addingTimeInterval(-90_000), intensity: 2, trigger: .coffee, didResist: false),
                Craving(date: .now.addingTimeInterval(-140_000), intensity: 3, trigger: .afterMeal, didResist: true),
                Craving(date: .now.addingTimeInterval(-200_000), intensity: 2, trigger: .boredom, didResist: true)
            ]),
            coachSessionStore: InMemoryCoachSessionStore(),
            factProvider: RemoteHealthFactProvider(
                endpoint: URL(string: "https://example.com")!,
                fetcher: FailingFetcher()
            ),
            notificationService: NoopNotificationService()
        )
    }
}

/// Always fails so previews exercise the offline fallback path.
private struct FailingFetcher: DataFetching {
    func data(from url: URL) async throws -> Data { throw HealthFactError.badResponse }
}
