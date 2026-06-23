import Foundation

/// Abstracts "the current instant" so time-dependent logic can be tested
/// deterministically instead of reaching for `Date()` directly.
public protocol DateProviding: Sendable {
    func now() -> Date
}

/// Production implementation backed by the system clock.
public struct SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

/// Test double returning a fixed instant.
public struct FixedDateProvider: DateProviding {
    public let date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { date }
}
