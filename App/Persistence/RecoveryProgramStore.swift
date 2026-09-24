import Foundation
import BreatheCore

struct RecoveryPlatformState: Codable, Equatable {
    static let currentSchemaVersion = 1
    var schemaVersion = currentSchemaVersion
    var primaryProgramInstanceID: UUID?
    var programs: [RecoveryProgram] = []
    var urges: [UrgeEpisode] = []
    var behaviors: [BehaviorEpisode] = []
    var plans: [IfThenPlan] = []
    var riskWindows: [RiskWindow] = []
    var strategyObservations: [StrategyObservation] = []
    var pauseList: [PauseListItem] = []
    var supportContacts: [UUID: SupportContactConfiguration] = [:]
    var acknowledgedSafetyWarnings: Set<RecoveryProgramID> = []
    var discreetNotifications = true
    var didExplainPlatformMigration = false
}

@MainActor
@Observable
final class RecoveryProgramStore {
    nonisolated static let storageKey = "recovery_platform_state_v1"
    private let defaults: UserDefaults
    private(set) var state: RecoveryPlatformState

    init(defaults: UserDefaults = UserDefaults(suiteName: PlanStore.appGroup) ?? .standard,
         hasLegacyNicotineData: Bool = false, now: Date = .now) {
        self.defaults = defaults
        self.state = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(RecoveryPlatformState.self, from: $0) } ?? .init()
        if hasLegacyNicotineData, state.programs.isEmpty {
            let nicotine = RecoveryProgram(programID: .nicotine, createdAt: now, updatedAt: now,
                                           goal: RecoveryGoal(kind: "quit_now", startedAt: now))
            state.programs = [nicotine]
            state.primaryProgramInstanceID = nicotine.id
            persist()
        }
    }

    var primaryProgram: RecoveryProgram? {
        guard let id = state.primaryProgramInstanceID else { return nil }
        return state.programs.first { $0.id == id && $0.state != .archived }
    }

    var activePrograms: [RecoveryProgram] { state.programs.filter { $0.state == .active } }

    @discardableResult func start(_ id: RecoveryProgramID, goalKind: String? = nil, now: Date = .now) -> RecoveryProgram {
        if let existing = state.programs.first(where: { $0.programID == id && $0.state != .archived }) {
            setPrimary(existing.id); return existing
        }
        let definition = RecoveryProgramCatalog.definition(id)
        let program = RecoveryProgram(programID: id, createdAt: now, updatedAt: now,
                                      goal: RecoveryGoal(kind: goalKind ?? definition.goalKinds[0], startedAt: now))
        state.programs.append(program); state.primaryProgramInstanceID = program.id; persist(); return program
    }

    func setPrimary(_ id: UUID) {
        guard let index = state.programs.firstIndex(where: { $0.id == id && $0.state != .archived }) else { return }
        if state.programs[index].state == .paused { state.programs[index].state = .active }
        state.primaryProgramInstanceID = id; persist()
    }

    func setState(_ value: RecoveryProgramState, for id: UUID) {
        guard let index = state.programs.firstIndex(where: { $0.id == id }) else { return }
        state.programs[index].state = value; state.programs[index].updatedAt = .now
        if value != .active, state.primaryProgramInstanceID == id {
            state.primaryProgramInstanceID = state.programs.first { $0.id != id && $0.state == .active }?.id
        }
        persist()
    }

    func add(_ urge: UrgeEpisode) { state.urges.append(urge); persist() }
    func add(_ behavior: BehaviorEpisode) { state.behaviors.append(behavior); persist() }
    func save(_ plan: IfThenPlan) { state.plans.removeAll { $0.id == plan.id }; state.plans.append(plan); persist() }
    func save(_ window: RiskWindow) { state.riskWindows.removeAll { $0.id == window.id }; state.riskWindows.append(window); persist() }
    func save(_ item: PauseListItem) { state.pauseList.removeAll { $0.id == item.id }; state.pauseList.append(item); persist() }
    func add(_ observation: StrategyObservation) { state.strategyObservations.append(observation); persist() }
    func acknowledgeSafety(for id: RecoveryProgramID) { state.acknowledgedSafetyWarnings.insert(id); persist() }
    func setDiscreetNotifications(_ enabled: Bool) { state.discreetNotifications = enabled; persist() }
    func markMigrationExplanationSeen() { state.didExplainPlatformMigration = true; persist() }

    func deleteProgram(_ id: UUID) {
        state.programs.removeAll { $0.id == id }; state.urges.removeAll { $0.programInstanceID == id }
        state.behaviors.removeAll { $0.programInstanceID == id }; state.plans.removeAll { $0.programInstanceID == id }
        state.riskWindows.removeAll { $0.programInstanceID == id }; state.pauseList.removeAll { $0.programInstanceID == id }
        state.supportContacts.removeValue(forKey: id)
        if state.primaryProgramInstanceID == id { state.primaryProgramInstanceID = state.activeProgramsFallback }
        persist()
    }

    func exportData() throws -> Data { try JSONEncoder.breatheExport.encode(state) }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
        defaults.set(primaryProgram?.programID.rawValue, forKey: "active_program_id")
        defaults.set(state.discreetNotifications, forKey: "discreet_notifications")
    }
}

private extension RecoveryPlatformState {
    var activeProgramsFallback: UUID? { programs.first { $0.state == .active }?.id }
}

private extension JSONEncoder {
    static var breatheExport: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder }
}
