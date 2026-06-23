import Foundation

/// The user's smoking baseline and the moment they decided to quit.
///
/// `QuitPlan` is the single source of truth from which every piece of
/// progress is derived. It is an immutable value type so it can be passed
/// safely across concurrency domains.
public struct QuitPlan: Sendable, Hashable, Codable {
    /// The instant the user stopped smoking.
    public var quitDate: Date

    /// How many cigarettes the user smoked per day before quitting.
    public var cigarettesPerDay: Int

    /// Number of cigarettes in a single pack (used to convert avoided
    /// cigarettes into avoided packs for the money calculation).
    public var cigarettesPerPack: Int

    /// Price of one pack, in minor-unit-free decimal form (e.g. 12.50).
    /// `Decimal` is used deliberately — money should never live in a `Double`.
    public var pricePerPack: Decimal

    /// ISO 4217 currency code, e.g. "USD", "EUR", "UAH".
    public var currencyCode: String

    /// Estimated minutes of life lost per cigarette. The widely cited figure
    /// is ~11 minutes; exposed here so it stays configurable and testable.
    public var minutesOfLifePerCigarette: Double

    public init(
        quitDate: Date,
        cigarettesPerDay: Int,
        cigarettesPerPack: Int = 20,
        pricePerPack: Decimal,
        currencyCode: String = "USD",
        minutesOfLifePerCigarette: Double = 11
    ) {
        self.quitDate = quitDate
        self.cigarettesPerDay = cigarettesPerDay
        self.cigarettesPerPack = cigarettesPerPack
        self.pricePerPack = pricePerPack
        self.currencyCode = currencyCode
        self.minutesOfLifePerCigarette = minutesOfLifePerCigarette
    }
}

public extension QuitPlan {
    /// Average price of a single cigarette.
    var pricePerCigarette: Decimal {
        guard cigarettesPerPack > 0 else { return 0 }
        return pricePerPack / Decimal(cigarettesPerPack)
    }
}
