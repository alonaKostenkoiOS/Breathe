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
    let calculator: ProgressCalculator
    let milestoneEngine: MilestoneEngine
    let dateProvider: any DateProviding

    init(
        planStore: PlanStore,
        cravingStore: any CravingStoring,
        factProvider: any HealthFactProviding,
        calculator: ProgressCalculator = .init(),
        milestoneEngine: MilestoneEngine = .init(),
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.planStore = planStore
        self.cravingStore = cravingStore
        self.factProvider = factProvider
        self.calculator = calculator
        self.milestoneEngine = milestoneEngine
        self.dateProvider = dateProvider
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
        return AppEnvironment(
            planStore: store,
            cravingStore: InMemoryCravingStore([
                Craving(date: .now.addingTimeInterval(-3_600), intensity: 4, trigger: .stress, didResist: true),
                Craving(date: .now.addingTimeInterval(-90_000), intensity: 2, trigger: .coffee, didResist: false)
            ]),
            factProvider: RemoteHealthFactProvider(
                endpoint: URL(string: "https://example.com")!,
                fetcher: FailingFetcher()
            )
        )
    }
}

/// Always fails so previews exercise the offline fallback path.
private struct FailingFetcher: DataFetching {
    func data(from url: URL) async throws -> Data { throw HealthFactError.badResponse }
}
