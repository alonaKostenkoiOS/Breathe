import Foundation

/// A short motivational health fact shown on the dashboard. Fetched from a
/// remote source so content can change without an app update, with a bundled
/// fallback for offline use.
public struct HealthFact: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let text: String
    public let source: String?

    public init(id: String, text: String, source: String? = nil) {
        self.id = id
        self.text = text
        self.source = source
    }
}

public extension HealthFact {
    /// Bundled facts used when the network is unavailable, so the dashboard
    /// is never empty. Offline-first by design.
    static let fallback: [HealthFact] = [
        HealthFact(
            id: "fallback-oxygen",
            text: "Within a day of quitting, the carbon monoxide in your blood drops and oxygen reaches your heart and muscles more easily.",
            source: "CDC"
        ),
        HealthFact(
            id: "fallback-taste",
            text: "Most people notice food tasting better within just two days of their last cigarette.",
            source: "NHS"
        ),
        HealthFact(
            id: "fallback-heart",
            text: "One year smoke-free roughly halves your excess risk of coronary heart disease.",
            source: "American Heart Association"
        )
    ]
}
