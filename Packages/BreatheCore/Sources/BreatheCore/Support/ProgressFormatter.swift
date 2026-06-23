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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(amount) \(currencyCode)"
    }

    /// A compact smoke-free duration, e.g. "12d 4h" or "3h 20m".
    public func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Life regained rendered in the largest sensible unit.
    public func lifeRegained(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 1_440 {
            let days = minutes / 1_440
            let hours = (minutes % 1_440) / 60
            return "\(days)d \(hours)h"
        }
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
