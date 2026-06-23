import Foundation

/// A point on the body's recovery timeline after the last cigarette.
///
/// The catalogue is grounded in public health guidance (NHS / CDC smoking
/// cessation timelines). Offsets are measured from the quit instant.
public struct HealthMilestone: Sendable, Hashable, Identifiable, Codable {
    public enum Category: String, Sendable, Codable, CaseIterable {
        case heart
        case circulation
        case lungs
        case senses
        case cancerRisk
    }

    public let id: String
    public let title: String
    public let detail: String
    /// Seconds after the quit instant at which this milestone is reached.
    public let offset: TimeInterval
    public let category: Category

    public init(
        id: String,
        title: String,
        detail: String,
        offset: TimeInterval,
        category: Category
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.offset = offset
        self.category = category
    }
}

/// The current state of a milestone relative to a reference instant.
public struct MilestoneStatus: Sendable, Hashable, Identifiable {
    public let milestone: HealthMilestone
    public let isAchieved: Bool
    /// 0...1 progress toward this milestone (1 once achieved).
    public let fraction: Double
    /// The calendar date this milestone is (or was) reached.
    public let reachedAt: Date

    public var id: String { milestone.id }

    public init(
        milestone: HealthMilestone,
        isAchieved: Bool,
        fraction: Double,
        reachedAt: Date
    ) {
        self.milestone = milestone
        self.isAchieved = isAchieved
        self.fraction = fraction
        self.reachedAt = reachedAt
    }
}

public extension HealthMilestone {
    /// The canonical recovery timeline, ordered from soonest to latest.
    static let catalogue: [HealthMilestone] = [
        HealthMilestone(
            id: "pulse-20min",
            title: "Pulse normalises",
            detail: "Heart rate and blood pressure begin to drop back toward normal.",
            offset: 20 * 60,
            category: .heart
        ),
        HealthMilestone(
            id: "co-12h",
            title: "Carbon monoxide clears",
            detail: "Carbon monoxide in your blood falls to a normal level, so more oxygen reaches your organs.",
            offset: 12 * 3_600,
            category: .circulation
        ),
        HealthMilestone(
            id: "heart-24h",
            title: "Heart attack risk falls",
            detail: "Your risk of a heart attack starts to decrease.",
            offset: 24 * 3_600,
            category: .heart
        ),
        HealthMilestone(
            id: "senses-48h",
            title: "Taste & smell return",
            detail: "Nerve endings start to regrow and your senses of smell and taste sharpen.",
            offset: 48 * 3_600,
            category: .senses
        ),
        HealthMilestone(
            id: "breathing-72h",
            title: "Breathing eases",
            detail: "Bronchial tubes relax and lung capacity increases, making breathing easier.",
            offset: 72 * 3_600,
            category: .lungs
        ),
        HealthMilestone(
            id: "circulation-2w",
            title: "Circulation improves",
            detail: "Blood flow improves, making walking and exercise noticeably easier.",
            offset: 14 * 86_400,
            category: .circulation
        ),
        HealthMilestone(
            id: "lungs-1m",
            title: "Lungs clear out",
            detail: "Cilia regrow, clearing mucus and cutting coughing and shortness of breath.",
            offset: 30 * 86_400,
            category: .lungs
        ),
        HealthMilestone(
            id: "lungs-3m",
            title: "Lung function climbs",
            detail: "Lung function can improve by up to 30%.",
            offset: 90 * 86_400,
            category: .lungs
        ),
        HealthMilestone(
            id: "heart-1y",
            title: "Heart disease risk halves",
            detail: "Your risk of coronary heart disease is about half that of a smoker.",
            offset: 365 * 86_400,
            category: .heart
        ),
        HealthMilestone(
            id: "cancer-5y",
            title: "Cancer risk drops",
            detail: "Risk of several cancers falls and stroke risk approaches that of a non-smoker.",
            offset: 5 * 365 * 86_400,
            category: .cancerRisk
        ),
        HealthMilestone(
            id: "lung-cancer-10y",
            title: "Lung cancer risk halves",
            detail: "Your risk of dying from lung cancer is roughly half that of a smoker.",
            offset: 10 * 365 * 86_400,
            category: .cancerRisk
        )
    ]
}
