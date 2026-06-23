import Foundation
import Observation
import BreatheCore

@MainActor
@Observable
final class CravingsViewModel {
    private(set) var cravings: [Craving] = []
    private(set) var insights: CravingInsights = .empty

    private let store: any CravingStoring
    private let analyzer: CravingAnalyzer
    private let dateProvider: any DateProviding

    init(environment: AppEnvironment, analyzer: CravingAnalyzer = .init()) {
        self.store = environment.cravingStore
        self.analyzer = analyzer
        self.dateProvider = environment.dateProvider
    }

    func load() async {
        do {
            cravings = try await store.all()
            insights = analyzer.insights(from: cravings)
        } catch {
            cravings = []
            insights = .empty
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
