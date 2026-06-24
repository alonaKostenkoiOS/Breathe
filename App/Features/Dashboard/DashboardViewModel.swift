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
    private(set) var goal: SavingsGoal?
    private(set) var goalProgress: GoalProgress?

    private let calculator: ProgressCalculator
    private let milestoneEngine: MilestoneEngine
    private let goalCalculator: SavingsGoalCalculator
    private let factProvider: any HealthFactProviding
    private let dateProvider: any DateProviding
    private let planStore: PlanStore

    init(environment: AppEnvironment) {
        self.calculator = environment.calculator
        self.milestoneEngine = environment.milestoneEngine
        self.goalCalculator = environment.goalCalculator
        self.factProvider = environment.factProvider
        self.dateProvider = environment.dateProvider
        self.planStore = environment.planStore
        self.plan = environment.planStore.plan
    }

    /// Recomputes the derived values for the current instant.
    func refresh() {
        // Re-read the plan and goal so edits in Settings show up live.
        plan = planStore.plan
        goal = planStore.goal
        guard let plan else { return }
        let now = dateProvider.now()
        progress = calculator.progress(for: plan, at: now)
        nextMilestone = milestoneEngine.nextMilestone(for: plan, at: now)
        if let goal {
            goalProgress = goalCalculator.progress(goal: goal, plan: plan, at: now)
        } else {
            goalProgress = nil
        }
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
