import AppIntents
import BreatheCore

/// Lets the user log a craving from Siri, Spotlight or the Shortcuts app —
/// "Hey Siri, log a craving in Breathe" — capturing the moment without
/// having to open the app and lose the fight.
struct LogCravingIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a craving"
    static let description = IntentDescription("Record a craving and whether you resisted it.")

    @Parameter(title: "Intensity", default: 3, controlStyle: .stepper, inclusiveRange: (1, 5))
    var intensity: Int

    @Parameter(title: "I resisted it", default: true)
    var didResist: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SwiftDataCravingStore(modelContainer: SharedContainer.make())
        let craving = Craving(
            date: Date(),
            intensity: intensity,
            trigger: .other,
            didResist: didResist
        )
        try await store.add(craving)

        let dialog: IntentDialog = didResist
            ? "Logged. Every craving you resist is progress."
            : "Logged. You had a slip, and your progress still matters."
        return .result(dialog: dialog)
    }
}

/// Surfaces the intent as a ready-made shortcut.
struct BreatheShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogCravingIntent(),
            phrases: ["Log a craving in \(.applicationName)"],
            shortTitle: "Log craving",
            systemImageName: "bolt.heart"
        )
        AppShortcut(intent: StartRescueIntent(), phrases: ["Start Rescue in \(.applicationName)"], shortTitle: "Start Rescue", systemImageName: "wind")
        AppShortcut(intent: LogUrgeIntent(), phrases: ["Log an urge in \(.applicationName)"], shortTitle: "Log urge", systemImageName: "waveform.path.ecg")
    }
}

struct StartRescueIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rescue"
    static let description = IntentDescription("Open immediate, private support in Breathe.")
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Take one slow breath. Breathe is ready when you are.")
    }
}

struct LogUrgeIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an urge"
    static let description = IntentDescription("Privately record an urge for your active Breathe program.")
    @Parameter(title: "Intensity", default: 3, controlStyle: .stepper, inclusiveRange: (1, 5)) var intensity: Int

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let planStore = PlanStore()
        let store = RecoveryProgramStore(hasLegacyNicotineData: planStore.isOnboardingComplete)
        guard let program = store.primaryProgram else { return .result(dialog: "Open Breathe to choose a program first.") }
        store.add(UrgeEpisode(programInstanceID: program.id, intensity: intensity, outcome: .stillDealingWithIt))
        return .result(dialog: "Logged privately. Your progress still matters.")
    }
}
