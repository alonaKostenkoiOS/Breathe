import Foundation

public enum RecoveryProgramID: String, Codable, CaseIterable, Sendable, Identifiable {
    case nicotine, digital, spending, alcohol, gambling
    public var id: String { rawValue }
}

public enum RecoveryProgramState: String, Codable, Sendable { case active, paused, archived }

public struct RecoveryProgram: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let programID: RecoveryProgramID
    public var state: RecoveryProgramState
    public let createdAt: Date
    public var updatedAt: Date
    public var goal: RecoveryGoal

    public init(id: UUID = UUID(), programID: RecoveryProgramID, state: RecoveryProgramState = .active,
                createdAt: Date = .now, updatedAt: Date = .now, goal: RecoveryGoal) {
        self.id = id; self.programID = programID; self.state = state
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.goal = goal
    }
}

public struct RecoveryGoal: Codable, Sendable, Equatable {
    public var kind: String
    public var startedAt: Date
    public var target: Decimal?
    public var currencyCode: String?
    public init(kind: String, startedAt: Date = .now, target: Decimal? = nil, currencyCode: String? = nil) {
        self.kind = kind; self.startedAt = startedAt; self.target = target; self.currencyCode = currencyCode
    }
}

public enum EpisodeOutcome: String, Codable, CaseIterable, Sendable {
    case urgePassed, delayed, reduced, behaviorOccurred, stillDealingWithIt
}

public enum ProgramContext: String, Codable, CaseIterable, Sendable {
    case home, work, social, travel, online, store, evening, other
}

public struct UrgeEpisode: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let programInstanceID: UUID
    public let occurredAt: Date
    public var intensity: Int
    public var triggerID: String?
    public var context: ProgramContext?
    public var outcome: EpisodeOutcome
    public var note: String?
    public init(id: UUID = UUID(), programInstanceID: UUID, occurredAt: Date = .now,
                intensity: Int, triggerID: String? = nil, context: ProgramContext? = nil,
                outcome: EpisodeOutcome, note: String? = nil) {
        self.id = id; self.programInstanceID = programInstanceID; self.occurredAt = occurredAt
        self.intensity = min(max(intensity, 1), 5); self.triggerID = triggerID
        self.context = context; self.outcome = outcome; self.note = note
    }
}

public enum BehaviorPayload: Codable, Sendable, Equatable {
    case nicotine(product: String, uses: Int)
    case digital(bundleIdentifier: String?, seconds: Int, intentional: Bool)
    case spending(amount: Decimal, currencyCode: String, wasPlanned: Bool)
    case alcohol(standardDrinks: Decimal)
    case gambling(amount: Decimal?, currencyCode: String?, seconds: Int)
}

public struct BehaviorEpisode: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let programInstanceID: UUID
    public let occurredAt: Date
    public let payload: BehaviorPayload
    public init(id: UUID = UUID(), programInstanceID: UUID, occurredAt: Date = .now, payload: BehaviorPayload) {
        self.id = id; self.programInstanceID = programInstanceID; self.occurredAt = occurredAt; self.payload = payload
    }
}

public enum PauseListDecision: String, Codable, Sendable { case waiting, purchased, declined }
public struct PauseListItem: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID; public let programInstanceID: UUID
    public var item: String; public var price: Decimal; public var currencyCode: String
    public var reason: String?; public var dateAdded: Date; public var reviewAt: Date
    public var decision: PauseListDecision; public var imageBookmark: Data?
    public init(id: UUID = UUID(), programInstanceID: UUID, item: String, price: Decimal,
                currencyCode: String, reason: String? = nil, dateAdded: Date = .now,
                reviewAt: Date, decision: PauseListDecision = .waiting, imageBookmark: Data? = nil) {
        self.id = id; self.programInstanceID = programInstanceID; self.item = item
        self.price = price; self.currencyCode = currencyCode; self.reason = reason
        self.dateAdded = dateAdded; self.reviewAt = reviewAt; self.decision = decision
        self.imageBookmark = imageBookmark
    }
}

public struct IfThenPlan: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID; public let programInstanceID: UUID
    public var ifText: String; public var thenText: String
    public var riskWindowID: UUID?; public var isArchived: Bool
    public init(id: UUID = UUID(), programInstanceID: UUID, ifText: String, thenText: String,
                riskWindowID: UUID? = nil, isArchived: Bool = false) {
        self.id = id; self.programInstanceID = programInstanceID; self.ifText = ifText
        self.thenText = thenText; self.riskWindowID = riskWindowID; self.isArchived = isArchived
    }
}

public enum RiskWindowSource: String, Codable, Sendable { case manual, suggested }
public struct RiskWindow: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID; public let programInstanceID: UUID
    public var localHour: Int; public var localMinute: Int; public var weekday: Int?
    public var source: RiskWindowSource; public var basis: String?; public var isEnabled: Bool
    public init(id: UUID = UUID(), programInstanceID: UUID, localHour: Int, localMinute: Int,
                weekday: Int? = nil, source: RiskWindowSource = .manual, basis: String? = nil, isEnabled: Bool = true) {
        self.id = id; self.programInstanceID = programInstanceID; self.localHour = min(max(localHour, 0), 23)
        self.localMinute = min(max(localMinute, 0), 59); self.weekday = weekday
        self.source = source; self.basis = basis; self.isEnabled = isEnabled
    }
}

public enum InsightConfidence: String, Codable, Sendable { case early, emerging, established }
public struct PersonalInsight: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID; public let programInstanceID: UUID
    public let strategyID: String; public let helpful: Int; public let observations: Int
    public let confidence: InsightConfidence
    public init(id: UUID = UUID(), programInstanceID: UUID, strategyID: String, helpful: Int, observations: Int) {
        self.id = id; self.programInstanceID = programInstanceID; self.strategyID = strategyID
        self.helpful = helpful; self.observations = observations
        self.confidence = observations >= 12 ? .established : observations >= 5 ? .emerging : .early
    }
}

public struct WeeklyExperiment: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID; public let programInstanceID: UUID
    public var titleKey: String; public var startedAt: Date; public var completedAt: Date?
    public init(id: UUID = UUID(), programInstanceID: UUID, titleKey: String, startedAt: Date = .now, completedAt: Date? = nil) {
        self.id = id; self.programInstanceID = programInstanceID; self.titleKey = titleKey
        self.startedAt = startedAt; self.completedAt = completedAt
    }
}

public struct SupportContactConfiguration: Codable, Sendable, Equatable {
    public var displayName: String?; public var actionURL: URL?
    public init(displayName: String? = nil, actionURL: URL? = nil) { self.displayName = displayName; self.actionURL = actionURL }
}

public struct ProgressSnapshot: Sendable, Equatable {
    public var primaryValue: Decimal; public var secondaryValue: Decimal; public var episodeCount: Int
    public init(primaryValue: Decimal = 0, secondaryValue: Decimal = 0, episodeCount: Int = 0) {
        self.primaryValue = primaryValue; self.secondaryValue = secondaryValue; self.episodeCount = episodeCount
    }
}

public enum SafetyEscalation: String, Codable, Sendable { case none, professionalSupport, urgentSupport, emergency }
public struct ProgramSafetyPolicy: Sendable, Equatable {
    public let requiresScreening: Bool; public let crisisPathAvailable: Bool
    public init(requiresScreening: Bool, crisisPathAvailable: Bool) {
        self.requiresScreening = requiresScreening; self.crisisPathAvailable = crisisPathAvailable
    }
}
public struct SupportResourcePolicy: Sendable, Equatable {
    public let includesProfessional: Bool; public let includesCrisis: Bool; public let includesSelfExclusion: Bool
    public init(includesProfessional: Bool, includesCrisis: Bool, includesSelfExclusion: Bool = false) {
        self.includesProfessional = includesProfessional; self.includesCrisis = includesCrisis; self.includesSelfExclusion = includesSelfExclusion
    }
}

public struct RecoveryProgramDefinition: Sendable, Equatable {
    public let id: RecoveryProgramID; public let nameKey: String; public let descriptionKey: String
    public let iconName: String; public let goalKinds: [String]; public let strategyIDs: [String]
    public let safetyPolicy: ProgramSafetyPolicy; public let resourcePolicy: SupportResourcePolicy
}

public enum RecoveryProgramCatalog {
    public static func definition(_ id: RecoveryProgramID) -> RecoveryProgramDefinition {
        switch id {
        case .nicotine: .init(id: id, nameKey: "program.nicotine.name", descriptionKey: "program.nicotine.description", iconName: "leaf.fill", goalKinds: ["quit_now", "prepare", "reduce", "nicotine_free"], strategyIDs: ["breathe", "urge_surf", "water", "walk", "delay", "contact"], safetyPolicy: .init(requiresScreening: false, crisisPathAvailable: false), resourcePolicy: .init(includesProfessional: true, includesCrisis: false))
        case .digital: .init(id: id, nameKey: "program.digital.name", descriptionKey: "program.digital.description", iconName: "iphone.slash", goalKinds: ["social_media", "automatic_checking", "bedtime", "focus"], strategyIDs: ["intention", "put_down", "focus_timer", "alternative", "delay"], safetyPolicy: .init(requiresScreening: false, crisisPathAvailable: false), resourcePolicy: .init(includesProfessional: false, includesCrisis: false))
        case .spending: .init(id: id, nameKey: "program.spending.name", descriptionKey: "program.spending.description", iconName: "cart.badge.clock", goalKinds: ["pause", "planned_only", "retain_money"], strategyIDs: ["pause_list", "compare_goal", "leave", "remove_card", "contact"], safetyPolicy: .init(requiresScreening: false, crisisPathAvailable: false), resourcePolicy: .init(includesProfessional: false, includesCrisis: false))
        case .alcohol: .init(id: id, nameKey: "program.alcohol.name", descriptionKey: "program.alcohol.description", iconName: "drop.fill", goalKinds: ["alcohol_free_days", "user_limit", "prepare_events"], strategyIDs: ["delay", "alternative", "leave", "contact", "transport", "professional"], safetyPolicy: .init(requiresScreening: true, crisisPathAvailable: true), resourcePolicy: .init(includesProfessional: true, includesCrisis: true))
        case .gambling: .init(id: id, nameKey: "program.gambling.name", descriptionKey: "program.gambling.description", iconName: "shield.lefthalf.filled", goalKinds: ["stop", "delay_deposits", "self_exclusion"], strategyIDs: ["delay_deposit", "close_app", "cooling_off", "contact", "self_exclusion", "professional"], safetyPolicy: .init(requiresScreening: true, crisisPathAvailable: true), resourcePolicy: .init(includesProfessional: true, includesCrisis: true, includesSelfExclusion: true))
        }
    }
}
