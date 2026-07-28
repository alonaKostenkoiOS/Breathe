import Foundation

/// Stable, locally persisted answers used to personalize support. `QuitPlan`
/// remains the calculation model so existing progress behavior is unchanged.
public struct QuitProfile: Codable, Sendable, Equatable {
    public var quitDate: Date
    public var cigarettesPerDay: Int
    public var cigarettesPerPack: Int
    public var packPrice: Decimal
    public var currencyCode: String
    public var firstCigaretteTiming: FirstCigaretteTiming
    public var triggers: Set<SmokingTrigger>
    public var routineEvents: [RoutineEvent]
    public var motivations: Set<QuitMotivation>
    public var personalReason: String?
    public var savingsGoal: SavingsGoal?
    public var savingsGoalEmoji: String?
    public var notificationPreferences: NotificationPreferences
    public var onboardingCompletedAt: Date?

    public init(
        quitDate: Date,
        cigarettesPerDay: Int,
        cigarettesPerPack: Int = 20,
        packPrice: Decimal,
        currencyCode: String,
        firstCigaretteTiming: FirstCigaretteTiming = .within60Minutes,
        triggers: Set<SmokingTrigger> = [],
        routineEvents: [RoutineEvent] = [],
        motivations: Set<QuitMotivation> = [],
        personalReason: String? = nil,
        savingsGoal: SavingsGoal? = nil,
        savingsGoalEmoji: String? = nil,
        notificationPreferences: NotificationPreferences = .init(),
        onboardingCompletedAt: Date? = nil
    ) {
        self.quitDate = quitDate
        self.cigarettesPerDay = cigarettesPerDay
        self.cigarettesPerPack = cigarettesPerPack
        self.packPrice = packPrice
        self.currencyCode = currencyCode
        self.firstCigaretteTiming = firstCigaretteTiming
        self.triggers = triggers
        self.routineEvents = routineEvents
        self.motivations = motivations
        self.personalReason = personalReason
        self.savingsGoal = savingsGoal
        self.savingsGoalEmoji = savingsGoalEmoji
        self.notificationPreferences = notificationPreferences
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    public var quitPlan: QuitPlan {
        QuitPlan(quitDate: quitDate, cigarettesPerDay: cigarettesPerDay,
                 cigarettesPerPack: cigarettesPerPack, pricePerPack: packPrice,
                 currencyCode: currencyCode)
    }
}

public enum JourneyStatus: String, Codable, Sendable, CaseIterable {
    case alreadyQuit = "already_quit"
    case quittingToday = "quitting_today"
    // Reserved for a future UI: case preparingToQuit = "preparing_to_quit"
}

public enum FirstCigaretteTiming: String, Codable, Sendable, CaseIterable {
    case within5Minutes = "within_5_minutes"
    case within30Minutes = "within_30_minutes"
    case within60Minutes = "within_60_minutes"
    case after60Minutes = "after_60_minutes"
}

public enum SmokingTrigger: String, Codable, Sendable, CaseIterable {
    case morningCoffee = "morning_coffee"
    case afterMeals = "after_meals"
    case workBreaks = "work_breaks"
    case stress, boredom, alcohol, driving
    case socialSituations = "social_situations"
    case seeingOthersSmoke = "seeing_others_smoke"
    case beforeBed = "before_bed"
    case other
}

public enum RoutineEventType: String, Codable, Sendable, CaseIterable {
    case morningCoffee = "morning_coffee"
    case breakfast, lunch
    case workBreak = "work_break"
    case dinner, evening, bedtime
}

public struct RoutineEvent: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var type: RoutineEventType
    public var localHour: Int
    public var localMinute: Int
    public var isEnabled: Bool

    public init(id: UUID = UUID(), type: RoutineEventType, localHour: Int,
                localMinute: Int, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.localHour = min(max(localHour, 0), 23)
        self.localMinute = min(max(localMinute, 0), 59)
        self.isEnabled = isEnabled
    }
}

public enum QuitMotivation: String, Codable, Sendable, CaseIterable {
    case betterHealth = "better_health"
    case saveMoney = "save_money"
    case familyRelationships = "family_relationships"
    case moreEnergy = "more_energy"
    case appearance
    case freedom = "freedom_from_addiction"
    case futureFamily = "future_family"
    case personal = "something_personal"
}

public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var difficultMoments: Bool
    public var milestones: Bool
    public var dailyCheckIn: Bool

    public init(difficultMoments: Bool = true, milestones: Bool = true,
                dailyCheckIn: Bool = false) {
        self.difficultMoments = difficultMoments
        self.milestones = milestones
        self.dailyCheckIn = dailyCheckIn
    }
}

/// A resumable snapshot. Sensitive values stay in local UserDefaults only.
public struct OnboardingDraft: Codable, Sendable, Equatable {
    public var step: Int
    public var journeyStatus: JourneyStatus?
    public var profile: QuitProfile

    public init(step: Int = 0, journeyStatus: JourneyStatus? = nil, profile: QuitProfile) {
        self.step = step
        self.journeyStatus = journeyStatus
        self.profile = profile
    }
}
