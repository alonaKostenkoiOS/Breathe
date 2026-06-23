import Foundation

/// An immutable snapshot of how far the user has come, computed for a
/// specific reference instant. All values are derived — never stored — so
/// the snapshot is always internally consistent.
public struct Progress: Sendable, Hashable {
    /// How long the user has been smoke-free.
    public let timeSmokeFree: TimeInterval

    /// Cigarettes not smoked since quitting.
    public let cigarettesAvoided: Int

    /// Money kept in the user's pocket, in the plan's currency.
    public let moneySaved: Decimal

    /// Estimated life regained, expressed as a time interval.
    public let lifeRegained: TimeInterval

    public init(
        timeSmokeFree: TimeInterval,
        cigarettesAvoided: Int,
        moneySaved: Decimal,
        lifeRegained: TimeInterval
    ) {
        self.timeSmokeFree = timeSmokeFree
        self.cigarettesAvoided = cigarettesAvoided
        self.moneySaved = moneySaved
        self.lifeRegained = lifeRegained
    }

    /// A neutral zero snapshot, useful for previews and as a default.
    public static let zero = Progress(
        timeSmokeFree: 0,
        cigarettesAvoided: 0,
        moneySaved: 0,
        lifeRegained: 0
    )
}

public extension Progress {
    /// Whole days the user has been smoke-free.
    var daysSmokeFree: Int {
        Int(timeSmokeFree / 86_400)
    }
}
