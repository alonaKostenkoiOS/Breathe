import Foundation
import Testing
@testable import BreatheCore

@Suite("Craving Coach recommendations")
struct CoachRecommendationServiceTests {
    private let service = CoachRecommendationService()

    @Test("Recommendations use transparent trigger rules", arguments: [
        (Craving.Trigger.stress, CoachStrategyID.calmBreathing),
        (.coffee, .changeScene), (.afterMeal, .changeScene),
        (.boredom, .handsAndMouth), (.alcohol, .rememberWhy),
        (.social, .rememberWhy), (.other, .rideTheWave)
    ])
    func triggerRule(input: (Craving.Trigger, CoachStrategyID)) {
        let result = service.recommendation(trigger: input.0, history: [])
        #expect(result.primary == input.1)
        #expect(result.reason == .triggerMatch)
        #expect(!result.alternatives.contains(result.primary))
        #expect(result.alternatives.count == 2)
    }

    @Test("A strategy that helped before takes priority for the same trigger")
    func learnsFromCompletedSessions() {
        let history = [
            session(trigger: .stress, strategy: .fiveSenses, outcome: .improved),
            session(trigger: .stress, strategy: .fiveSenses, outcome: .improved),
            session(trigger: .stress, strategy: .calmBreathing, outcome: .unchanged),
            session(trigger: .coffee, strategy: .rideTheWave, outcome: .improved)
        ]
        let result = service.recommendation(trigger: .stress, history: history)
        #expect(result.primary == .fiveSenses)
        #expect(result.reason == .previouslyHelpful(2))
    }

    @Test("Persisted sessions retain stable raw-value data")
    func codingRoundTrip() throws {
        let original = session(trigger: .afterMeal, strategy: .changeScene, outcome: .improved)
        let restored = try JSONDecoder().decode(CoachSession.self, from: JSONEncoder().encode(original))
        #expect(restored == original)
        #expect(restored.selectedStrategyID?.rawValue == "changeScene")
    }

    private func session(trigger: Craving.Trigger, strategy: CoachStrategyID, outcome: CoachOutcome) -> CoachSession {
        CoachSession(entryPoint: .home, trigger: trigger, initialIntensity: 4,
                     finalIntensity: 2, recommendedStrategyID: strategy,
                     selectedStrategyID: strategy, outcome: outcome)
    }
}
