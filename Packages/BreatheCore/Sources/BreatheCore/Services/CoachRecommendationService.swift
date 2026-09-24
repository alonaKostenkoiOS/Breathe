import Foundation

public struct CoachRecommendation: Sendable, Equatable {
    public let primary: CoachStrategyID
    public let alternatives: [CoachStrategyID]
    public let reason: Reason

    public enum Reason: Sendable, Equatable { case triggerMatch, previouslyHelpful(Int), gettingStarted }
}

public struct CoachRecommendationService: Sendable {
    public init() {}

    public func recommendation(trigger: Craving.Trigger?, history: [CoachSession]) -> CoachRecommendation {
        let matching = history.filter {
            $0.trigger == trigger && $0.outcome == .improved && $0.selectedStrategyID != nil
        }
        let counts = Dictionary(grouping: matching, by: { $0.selectedStrategyID! }).mapValues(\.count)
        if let winner = counts.max(by: { $0.value < $1.value }) {
            return make(primary: winner.key, reason: .previouslyHelpful(winner.value))
        }
        guard let trigger else { return make(primary: .calmBreathing, reason: .gettingStarted) }
        let primary: CoachStrategyID = switch trigger {
        case .stress: .calmBreathing
        case .coffee: .changeScene
        case .alcohol: .rememberWhy
        case .afterMeal: .changeScene
        case .boredom: .handsAndMouth
        case .social: .rememberWhy
        case .other: .rideTheWave
        }
        return make(primary: primary, reason: .triggerMatch)
    }

    private func make(primary: CoachStrategyID, reason: CoachRecommendation.Reason) -> CoachRecommendation {
        let fallback: [CoachStrategyID] = [.calmBreathing, .rideTheWave, .fiveSenses, .changeScene, .handsAndMouth, .rememberWhy]
        return CoachRecommendation(primary: primary, alternatives: Array(fallback.filter { $0 != primary }.prefix(2)), reason: reason)
    }
}
