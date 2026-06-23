import Foundation
import Observation
import BreatheCore

/// Drives the dashboard: recomputes the live progress snapshot on a ticking
/// clock and loads the motivational fact of the day. All UI state lives here
/// so the view stays declarative and free of logic.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var progress: BreatheCore.Progress = .zero
    private(set) var nextMilestone: MilestoneStatus?
    private(set) var fact: HealthFact?
    private(set) var plan: QuitPlan?

    private let calculator: ProgressCalculator
    private let milestoneEngine: MilestoneEngine
    private let factProvider: any HealthFactProviding
    private let dateProvider: any DateProviding

    init(environment: AppEnvironment) {
        self.calculator = environment.calculator
        self.milestoneEngine = environment.milestoneEngine
        self.factProvider = environment.factProvider
        self.dateProvider = environment.dateProvider
        self.plan = environment.planStore.plan
    }

    /// Recomputes the derived values for the current instant.
    func refresh() {
        guard let plan else { return }
        let now = dateProvider.now()
        progress = calculator.progress(for: plan, at: now)
        nextMilestone = milestoneEngine.nextMilestone(for: plan, at: now)
    }

    /// Loads the fact of the day once when the view appears.
    func loadFact() async {
        fact = await factProvider.dailyFact(on: dateProvider.now())
    }

    /// Ticks once a second while the view is on screen, cancelling cleanly
    /// when the task is torn down.
    func startTicking() async {
        refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            refresh()
        }
    }
}
