import Foundation

/// How a single trigger contributed to the user's cravings.
public struct TriggerBreakdown: Sendable, Hashable, Identifiable {
    public let trigger: Craving.Trigger
    public let total: Int
    public let resisted: Int

    public var id: Craving.Trigger { trigger }
    /// Cravings of this trigger that were given in to.
    public var gaveIn: Int { total - resisted }

    public init(trigger: Craving.Trigger, total: Int, resisted: Int) {
        self.trigger = trigger
        self.total = total
        self.resisted = resisted
    }
}

/// How many cravings struck during a given hour of the day (0...23).
public struct HourlyCravings: Sendable, Hashable, Identifiable {
    public let hour: Int
    public let count: Int

    public var id: Int { hour }

    public init(hour: Int, count: Int) {
        self.hour = hour
        self.count = count
    }
}
