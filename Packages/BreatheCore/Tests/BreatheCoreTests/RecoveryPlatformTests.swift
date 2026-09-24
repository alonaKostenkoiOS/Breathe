import Foundation
import Testing
@testable import BreatheCore

@Suite("Modular recovery platform")
struct RecoveryPlatformTests {
    @Test("All five programs have distinct definitions and typed strategies")
    func programDefinitions() {
        #expect(RecoveryProgramID.allCases.count == 5)
        let definitions = RecoveryProgramID.allCases.map(RecoveryProgramCatalog.definition)
        #expect(Set(definitions.map(\.nameKey)).count == 5)
        #expect(definitions.allSatisfy { !$0.strategyIDs.isEmpty })
        #expect(RecoveryProgramCatalog.definition(.alcohol).safetyPolicy.requiresScreening)
        #expect(RecoveryProgramCatalog.definition(.gambling).resourcePolicy.includesSelfExclusion)
    }

    @Test("Program-specific behavior payloads round-trip without optional-field soup")
    func typedPayloadsRoundTrip() throws {
        let id = UUID()
        let values = [
            BehaviorEpisode(programInstanceID: id, payload: .digital(bundleIdentifier: nil, seconds: 300, intentional: true)),
            BehaviorEpisode(programInstanceID: id, payload: .spending(amount: 25, currencyCode: "UAH", wasPlanned: false)),
            BehaviorEpisode(programInstanceID: id, payload: .alcohol(standardDrinks: 1.5)),
            BehaviorEpisode(programInstanceID: id, payload: .gambling(amount: 10, currencyCode: "EUR", seconds: 60))
        ]
        let restored = try JSONDecoder().decode([BehaviorEpisode].self, from: JSONEncoder().encode(values))
        #expect(restored == values)
    }

    @Test("Safety rules escalate alcohol withdrawal warning signs")
    func alcoholSafety() {
        let service = ProgramSafetyService()
        var answers = AlcoholSafetyAnswers()
        #expect(service.alcoholEscalation(answers) == .none)
        answers.shakingOrSweating = true
        #expect(service.alcoholEscalation(answers) == .urgentSupport)
        answers.previousSeizure = true
        #expect(service.alcoholEscalation(answers) == .emergency)
    }

    @Test("Gambling self-harm concerns always expose crisis escalation")
    func gamblingSafety() {
        let service = ProgramSafetyService()
        #expect(service.gamblingEscalation(selfHarmConcern: true, immediateDanger: false) == .urgentSupport)
        #expect(service.gamblingEscalation(selfHarmConcern: false, immediateDanger: true) == .emergency)
    }

    @Test("Strategy ranking uses observations and rotates the last strategy")
    func strategyRanking() {
        let observations = (0..<6).map { _ in StrategyObservation(strategyID: "walk", programID: .nicotine, initialIntensity: 5, finalIntensity: 2, outcome: .urgePassed, helpful: true) }
        let service = PersonalStrategyRankingService()
        let ranked = service.rank(programID: .nicotine, candidates: ["walk", "breathe"], triggerID: nil, context: nil, observations: observations)
        #expect(ranked.first?.id == "walk")
        #expect(ranked.first?.confidence == .emerging)
        let rotated = service.rank(programID: .nicotine, candidates: ["walk", "breathe"], triggerID: nil, context: nil, observations: [], excludingLast: "walk")
        #expect(rotated.first?.id == "breathe")
    }

    @Test("Risk windows need repeated evidence and explain their basis")
    func riskSuggestions() {
        let id = UUID(); let calendar = Calendar(identifier: .gregorian)
        let episodes = (1...3).map { day -> UrgeEpisode in
            let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 14))!
            return UrgeEpisode(programInstanceID: id, occurredAt: date, intensity: 3, outcome: .delayed)
        }
        let result = RiskWindowSuggestionService().suggestions(programInstanceID: id, episodes: episodes, calendar: calendar)
        #expect(result.count == 1)
        #expect(result[0].basis?.contains("3") == true)
        #expect(result[0].source == .suggested)
    }

    @Test("A setback remains an episode and never destroys prior progress")
    func setbackPreservesHistory() {
        let id = UUID()
        let values = [UrgeEpisode(programInstanceID: id, intensity: 3, outcome: .urgePassed),
                      UrgeEpisode(programInstanceID: id, intensity: 4, outcome: .behaviorOccurred)]
        #expect(values.count == 2)
        #expect(values.first?.outcome == .urgePassed)
    }
}
