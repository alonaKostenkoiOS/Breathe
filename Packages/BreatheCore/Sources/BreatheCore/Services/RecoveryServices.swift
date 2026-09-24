import Foundation

public struct AlcoholSafetyAnswers: Codable, Sendable, Equatable {
    public var frequentHeavyUse = false; public var previousWithdrawal = false
    public var shakingOrSweating = false; public var previousSeizure = false
    public var hallucinationsOrConfusion = false; public var drinksToFeelNormal = false
    public var pregnancy = false; public var currentEmergency = false
    public init() {}
}

public struct ProgramSafetyService: Sendable {
    public init() {}
    public func alcoholEscalation(_ value: AlcoholSafetyAnswers) -> SafetyEscalation {
        if value.currentEmergency || value.previousSeizure || value.hallucinationsOrConfusion { return .emergency }
        if value.previousWithdrawal || value.shakingOrSweating || value.drinksToFeelNormal || value.pregnancy { return .urgentSupport }
        if value.frequentHeavyUse { return .professionalSupport }
        return .none
    }
    public func gamblingEscalation(selfHarmConcern: Bool, immediateDanger: Bool) -> SafetyEscalation {
        immediateDanger ? .emergency : selfHarmConcern ? .urgentSupport : .none
    }
}

public struct StrategyObservation: Codable, Sendable, Equatable {
    public var strategyID: String; public var programID: RecoveryProgramID
    public var triggerID: String?; public var context: ProgramContext?
    public var initialIntensity: Int; public var finalIntensity: Int
    public var outcome: EpisodeOutcome; public var helpful: Bool?; public var occurredAt: Date
    public init(strategyID: String, programID: RecoveryProgramID, triggerID: String? = nil,
                context: ProgramContext? = nil, initialIntensity: Int, finalIntensity: Int,
                outcome: EpisodeOutcome, helpful: Bool?, occurredAt: Date = .now) {
        self.strategyID = strategyID; self.programID = programID; self.triggerID = triggerID
        self.context = context; self.initialIntensity = initialIntensity; self.finalIntensity = finalIntensity
        self.outcome = outcome; self.helpful = helpful; self.occurredAt = occurredAt
    }
}

public struct RankedStrategy: Sendable, Equatable { public let id: String; public let score: Double; public let confidence: InsightConfidence }

public struct PersonalStrategyRankingService: Sendable {
    public init() {}
    public func rank(programID: RecoveryProgramID, candidates: [String], triggerID: String?, context: ProgramContext?,
                     observations: [StrategyObservation], excludingLast last: String? = nil) -> [RankedStrategy] {
        candidates.map { id in
            let matches = observations.filter { $0.programID == programID && $0.strategyID == id }
            let useful = matches.reduce(0.0) { score, item in
                score + (item.helpful == true ? 2 : item.helpful == false ? -1 : 0)
                    + Double(max(0, item.initialIntensity - item.finalIntensity))
                    + (item.outcome == .urgePassed || item.outcome == .delayed ? 1 : 0)
                    + (item.triggerID == triggerID && triggerID != nil ? 0.75 : 0)
                    + (item.context == context && context != nil ? 0.5 : 0)
            }
            let fatigue = last == id ? 1.5 : 0
            let confidence: InsightConfidence = matches.count >= 12 ? .established : matches.count >= 5 ? .emerging : .early
            return RankedStrategy(id: id, score: useful / Double(max(matches.count, 1)) - fatigue, confidence: confidence)
        }.sorted { $0.score > $1.score }
    }
}

public struct RiskWindowSuggestionService: Sendable {
    public init() {}
    public func suggestions(programInstanceID: UUID, episodes: [UrgeEpisode], calendar: Calendar = .current) -> [RiskWindow] {
        let grouped = Dictionary(grouping: episodes) { calendar.component(.hour, from: $0.occurredAt) }
        return grouped.filter { $0.value.count >= 3 }.map { hour, values in
            RiskWindow(programInstanceID: programInstanceID, localHour: hour, localMinute: 0,
                       source: .suggested, basis: "\(values.count) recent urges happened around this time.")
        }.sorted { $0.localHour < $1.localHour }
    }
}
