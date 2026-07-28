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
    let cravingStore: any CravingStoring
    let factProvider: any HealthFactProviding
    let notificationService: any NotificationScheduling
    let calculator: ProgressCalculator
    let milestoneEngine: MilestoneEngine
    let goalCalculator: SavingsGoalCalculator
    let analyzer: CravingAnalyzer
    let dateProvider: any DateProviding
    let onboardingAnalytics: any OnboardingAnalyticsTracking

    init(
        planStore: PlanStore,
        cravingStore: any CravingStoring,
        factProvider: any HealthFactProviding,
        notificationService: any NotificationScheduling = LocalNotificationService(),
        calculator: ProgressCalculator = .init(),
        milestoneEngine: MilestoneEngine = .init(),
        goalCalculator: SavingsGoalCalculator = .init(),
        analyzer: CravingAnalyzer = .init(),
        dateProvider: any DateProviding = SystemDateProvider(),
        onboardingAnalytics: any OnboardingAnalyticsTracking = NoopOnboardingAnalytics()
    ) {
        self.planStore = planStore
        self.cravingStore = cravingStore
        self.factProvider = factProvider
        self.notificationService = notificationService
        self.calculator = calculator
        self.milestoneEngine = milestoneEngine
        self.goalCalculator = goalCalculator
        self.analyzer = analyzer
        self.dateProvider = dateProvider
        self.onboardingAnalytics = onboardingAnalytics
    }

    /// The live environment used by the running app.
    static func live() -> AppEnvironment {
        let container = SharedContainer.make()
        let factsURL = URL(string: "https://raw.githubusercontent.com/breathe-app/facts/main/facts.json")!

        return AppEnvironment(
            planStore: PlanStore(),
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
            cravingStore: InMemoryCravingStore([
                Craving(date: .now.addingTimeInterval(-3_600), intensity: 4, trigger: .stress, didResist: true),
                Craving(date: .now.addingTimeInterval(-50_000), intensity: 5, trigger: .stress, didResist: false),
                Craving(date: .now.addingTimeInterval(-90_000), intensity: 2, trigger: .coffee, didResist: false),
                Craving(date: .now.addingTimeInterval(-140_000), intensity: 3, trigger: .afterMeal, didResist: true),
                Craving(date: .now.addingTimeInterval(-200_000), intensity: 2, trigger: .boredom, didResist: true)
            ]),
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
