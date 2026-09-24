import Foundation

/// Formats domain values into user-facing strings. Kept in the core so the
/// app and the widget render numbers identically.
public struct ProgressFormatter: Sendable {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// e.g. "$124.50" for the plan's currency.
    public func money(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// A compact smoke-free duration, e.g. "12d 4h" or "3h 20m".
    public func duration(_ interval: TimeInterval) -> String {
        durationFormatter.string(from: max(interval, 0)) ?? 0.formatted(.number.locale(locale))
    }

    /// Life regained rendered in the largest sensible unit.
    public func lifeRegained(_ interval: TimeInterval) -> String {
        duration(interval)
    }

    public func percentage(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.calendar?.locale = locale
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading, .dropTrailing]
        return formatter
    }
}
