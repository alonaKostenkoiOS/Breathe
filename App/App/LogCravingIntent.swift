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
            ? "Logged — and you beat it. Nice work."
            : "Logged. No judgement — tomorrow's another shot."
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
    }
}
