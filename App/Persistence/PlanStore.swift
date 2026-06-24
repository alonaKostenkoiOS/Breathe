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

    private let defaults: UserDefaults
    private(set) var plan: QuitPlan?
    private(set) var goal: SavingsGoal?

    init(defaults: UserDefaults = UserDefaults(suiteName: PlanStore.appGroup) ?? .standard) {
        self.defaults = defaults
        self.plan = Self.decode(QuitPlan.self, forKey: Self.planKey, from: defaults)
        self.goal = Self.decode(SavingsGoal.self, forKey: Self.goalKey, from: defaults)
    }

    var hasPlan: Bool { plan != nil }

    func save(_ plan: QuitPlan) {
        self.plan = plan
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: Self.planKey)
        }
    }

    func saveGoal(_ goal: SavingsGoal?) {
        self.goal = goal
        if let goal, let data = try? JSONEncoder().encode(goal) {
            defaults.set(data, forKey: Self.goalKey)
        } else {
            defaults.removeObject(forKey: Self.goalKey)
        }
    }

    func reset() {
        plan = nil
        goal = nil
        defaults.removeObject(forKey: Self.planKey)
        defaults.removeObject(forKey: Self.goalKey)
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
