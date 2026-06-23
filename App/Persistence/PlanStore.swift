import Foundation
import BreatheCore

/// Persists the single ``QuitPlan`` to a shared App Group container so both
/// the app and the widget read the same source of truth. Backed by
/// `UserDefaults` because a plan is one small value, not a collection.
@MainActor
@Observable
final class PlanStore {
    nonisolated static let appGroup = "group.com.breathe.app"
    private static let key = "quit_plan"

    private let defaults: UserDefaults
    private(set) var plan: QuitPlan?

    init(defaults: UserDefaults = UserDefaults(suiteName: PlanStore.appGroup) ?? .standard) {
        self.defaults = defaults
        self.plan = Self.load(from: defaults)
    }

    var hasPlan: Bool { plan != nil }

    func save(_ plan: QuitPlan) {
        self.plan = plan
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func reset() {
        plan = nil
        defaults.removeObject(forKey: Self.key)
    }

    private static func load(from defaults: UserDefaults) -> QuitPlan? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuitPlan.self, from: data)
    }
}
