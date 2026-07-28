import Foundation
import Observation
import BreatheCore

@MainActor
@Observable
final class CravingsViewModel {
    private(set) var cravings: [Craving] = []
    private(set) var insights: CravingInsights = .empty
    private(set) var triggerBreakdown: [TriggerBreakdown] = []
    private(set) var hourly: [HourlyCravings] = []
    private(set) var hasLoadError = false

    private let store: any CravingStoring
    private let analyzer: CravingAnalyzer
    private let dateProvider: any DateProviding

    init(environment: AppEnvironment) {
        self.store = environment.cravingStore
        self.analyzer = environment.analyzer
        self.dateProvider = environment.dateProvider
    }

    func load() async {
        do {
            hasLoadError = false
            cravings = try await store.all()
            insights = analyzer.insights(from: cravings)
            triggerBreakdown = analyzer.breakdownByTrigger(cravings)
            hourly = analyzer.cravingsByHour(cravings)
        } catch {
            hasLoadError = true
            cravings = []
            insights = .empty
            triggerBreakdown = []
            hourly = []
        }
    }

    func log(intensity: Int, trigger: Craving.Trigger, didResist: Bool, note: String?) async {
        let craving = Craving(
            date: dateProvider.now(),
            intensity: intensity,
            trigger: trigger,
            didResist: didResist,
            note: note?.isEmpty == true ? nil : note
        )
        try? await store.add(craving)
        await load()
    }

    func delete(_ craving: Craving) async {
        try? await store.delete(id: craving.id)
        await load()
    }
}
