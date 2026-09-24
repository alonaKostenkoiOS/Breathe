import Foundation

public enum CoachEntryPoint: String, Codable, Sendable, CaseIterable {
    case home, cravingLog, riskAlert, widget, shortcut, history
}

public enum CoachOutcome: String, Codable, Sendable, CaseIterable {
    case improved, unchanged, worsened, slipped, abandoned
}

public enum CoachStrategyID: String, Codable, Sendable, CaseIterable, Identifiable {
    case rideTheWave
    case calmBreathing
    case fiveSenses
    case changeScene
    case handsAndMouth
    case rememberWhy

    public var id: String { rawValue }
}

public struct CoachSession: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let startedAt: Date
    public var completedAt: Date?
    public let entryPoint: CoachEntryPoint
    public var trigger: Craving.Trigger?
    public var initialIntensity: Int
    public var finalIntensity: Int?
    public var recommendedStrategyID: CoachStrategyID?
    public var selectedStrategyID: CoachStrategyID?
    public var outcome: CoachOutcome?
    public var cravingID: UUID?

    public init(
        id: UUID = UUID(), startedAt: Date = .now, completedAt: Date? = nil,
        entryPoint: CoachEntryPoint, trigger: Craving.Trigger? = nil,
        initialIntensity: Int = 3, finalIntensity: Int? = nil,
        recommendedStrategyID: CoachStrategyID? = nil,
        selectedStrategyID: CoachStrategyID? = nil, outcome: CoachOutcome? = nil,
        cravingID: UUID? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.entryPoint = entryPoint
        self.trigger = trigger
        self.initialIntensity = min(max(initialIntensity, 1), 5)
        self.finalIntensity = finalIntensity.map { min(max($0, 1), 5) }
        self.recommendedStrategyID = recommendedStrategyID
        self.selectedStrategyID = selectedStrategyID
        self.outcome = outcome
        self.cravingID = cravingID
    }
}

public protocol CoachSessionStoring: Sendable {
    func all() async throws -> [CoachSession]
    func save(_ session: CoachSession) async throws
}

public actor InMemoryCoachSessionStore: CoachSessionStoring {
    private var sessions: [CoachSession]
    public init(_ sessions: [CoachSession] = []) { self.sessions = sessions }
    public func all() -> [CoachSession] { sessions.sorted { $0.startedAt > $1.startedAt } }
    public func save(_ session: CoachSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }
}
