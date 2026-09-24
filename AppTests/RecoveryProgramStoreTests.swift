import Foundation
import Testing
import BreatheCore
@testable import Breathe

@MainActor
@Suite("Versioned program storage and privacy")
struct RecoveryProgramStoreTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "RecoveryProgramTests.\(UUID().uuidString)")! }

    @Test("Existing users migrate automatically to nicotine without changing legacy values")
    func nicotineMigration() {
        let defaults = defaults()
        let planStore = PlanStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        planStore.save(QuitPlan(quitDate: date, cigarettesPerDay: 12, pricePerPack: 9, currencyCode: "UAH"))
        let store = RecoveryProgramStore(defaults: defaults, hasLegacyNicotineData: true, now: date)
        #expect(store.primaryProgram?.programID == .nicotine)
        #expect(planStore.plan?.quitDate == date)
        #expect(planStore.plan?.currencyCode == "UAH")
        #expect(defaults.data(forKey: "quit_plan") != nil)
    }

    @Test("Programs switch, pause, archive, and restore from versioned storage")
    func lifecycle() {
        let defaults = defaults(); let store = RecoveryProgramStore(defaults: defaults)
        let digital = store.start(.digital); let spending = store.start(.spending)
        #expect(store.primaryProgram?.id == spending.id)
        store.setPrimary(digital.id); #expect(store.primaryProgram?.id == digital.id)
        store.setState(.paused, for: digital.id); #expect(store.primaryProgram?.id == spending.id)
        store.setState(.archived, for: spending.id); #expect(store.primaryProgram == nil)
        let restored = RecoveryProgramStore(defaults: defaults)
        #expect(restored.state.programs.count == 2)
        #expect(restored.state.schemaVersion == RecoveryPlatformState.currentSchemaVersion)
    }

    @Test("Deleting one program removes only its sensitive rows")
    func scopedDeletion() {
        let store = RecoveryProgramStore(defaults: defaults())
        let digital = store.start(.digital); let spending = store.start(.spending)
        store.add(UrgeEpisode(programInstanceID: digital.id, intensity: 2, outcome: .delayed))
        store.add(UrgeEpisode(programInstanceID: spending.id, intensity: 4, outcome: .behaviorOccurred))
        store.save(IfThenPlan(programInstanceID: digital.id, ifText: "I reach for my phone", thenText: "I pause"))
        store.deleteProgram(digital.id)
        #expect(store.state.urges.count == 1)
        #expect(store.state.urges[0].programInstanceID == spending.id)
        #expect(store.state.plans.isEmpty)
    }

    @Test("Export is local Codable data and discreet widget state is shared")
    func exportAndPrivacy() throws {
        let defaults = defaults(); let store = RecoveryProgramStore(defaults: defaults)
        _ = store.start(.gambling); store.setDiscreetNotifications(true)
        let export = try store.exportData()
        #expect(!export.isEmpty)
        #expect(defaults.bool(forKey: "discreet_notifications"))
        #expect(defaults.string(forKey: "active_program_id") == "gambling")
    }

    @Test("Discreet notifications never include supplied sensitive copy")
    func discreetNotificationCopy() {
        let copy = NotificationCopy.make(title: "Alcohol risk", body: "You usually drink now", discreet: true, language: .english)
        #expect(!copy.title.contains("Alcohol"))
        #expect(!copy.body.contains("drink"))
    }

    @Test("Analytics event type cannot carry sensitive payload fields")
    func analyticsAllowList() {
        let event = RecoveryAnalyticsEvent.rescueCompleted
        #expect(event.rawValue == "rescue_completed")
        #expect(Mirror(reflecting: event).children.isEmpty)
    }
}
