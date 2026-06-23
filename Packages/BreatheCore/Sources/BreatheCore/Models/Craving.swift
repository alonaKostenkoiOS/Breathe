import Foundation

/// A logged moment of craving — the raw material for the app's insights
/// (which triggers hit hardest, what time of day, resistance rate).
public struct Craving: Sendable, Hashable, Identifiable, Codable {
    public enum Trigger: String, Sendable, Codable, CaseIterable {
        case stress
        case coffee
        case alcohol
        case afterMeal
        case boredom
        case social
        case other
    }

    public let id: UUID
    public let date: Date
    /// Subjective intensity, 1 (mild) ... 5 (overwhelming).
    public let intensity: Int
    public let trigger: Trigger
    /// Whether the user rode it out without smoking.
    public let didResist: Bool
    public let note: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        intensity: Int,
        trigger: Trigger,
        didResist: Bool,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.intensity = min(max(intensity, 1), 5)
        self.trigger = trigger
        self.didResist = didResist
        self.note = note
    }
}

/// Aggregate insights derived from a collection of cravings.
public struct CravingInsights: Sendable, Hashable {
    public let total: Int
    public let resisted: Int
    /// 0...1 share of cravings the user resisted.
    public let resistanceRate: Double
    /// The trigger that appears most often, if any.
    public let topTrigger: Craving.Trigger?

    public init(total: Int, resisted: Int, resistanceRate: Double, topTrigger: Craving.Trigger?) {
        self.total = total
        self.resisted = resisted
        self.resistanceRate = resistanceRate
        self.topTrigger = topTrigger
    }

    public static let empty = CravingInsights(total: 0, resisted: 0, resistanceRate: 0, topTrigger: nil)
}
