import Foundation
import Testing
@testable import BreatheCore

@Suite("SavingsGoalCalculator")
struct SavingsGoalTests {
    private let calculator = SavingsGoalCalculator()

    /// 20/day at $0.50 each → $10 saved per day.
    private func plan() -> QuitPlan {
        QuitPlan(
            quitDate: Date(timeIntervalSince1970: 0),
            cigarettesPerDay: 20,
            cigarettesPerPack: 20,
            pricePerPack: 10,
            currencyCode: "USD"
        )
    }

    @Test("Halfway to the target reports a 0.5 fraction and the remainder")
    func halfway() {
        // 5 days → $50 saved. Target $100.
        let progress = calculator.progress(
            goal: SavingsGoal(name: "Trip", target: 100),
            plan: plan(),
            at: Date(timeIntervalSince1970: 5 * 86_400)
        )
        #expect(progress.fraction == 0.5)
        #expect(progress.remaining == Decimal(50))
        #expect(!progress.isReached)
    }

    @Test("Reaching the target clamps the fraction and clears the remainder")
    func reached() {
        // 15 days → $150 saved, target $100.
        let progress = calculator.progress(
            goal: SavingsGoal(name: "Phone", target: 100),
            plan: plan(),
            at: Date(timeIntervalSince1970: 15 * 86_400)
        )
        #expect(progress.fraction == 1)
        #expect(progress.remaining == 0)
        #expect(progress.isReached)
        #expect(progress.eta == nil)
    }

    @Test("ETA projects the date the goal is reached from the daily rate")
    func eta() {
        // $50 saved at day 5, $50 to go at $10/day → 5 more days → day 10.
        let progress = calculator.progress(
            goal: SavingsGoal(name: "Trip", target: 100),
            plan: plan(),
            at: Date(timeIntervalSince1970: 5 * 86_400)
        )
        #expect(progress.eta == Date(timeIntervalSince1970: 10 * 86_400))
    }

    @Test("A zero or negative target is treated as already reached")
    func zeroTarget() {
        let progress = calculator.progress(
            goal: SavingsGoal(name: "None", target: 0),
            plan: plan(),
            at: Date(timeIntervalSince1970: 86_400)
        )
        #expect(progress.isReached)
        #expect(progress.fraction == 1)
    }
}

@Suite("CravingAnalyzer breakdowns")
struct CravingBreakdownTests {
    private let analyzer = CravingAnalyzer()

    private func craving(_ trigger: Craving.Trigger, hour: Int, resisted: Bool) -> Craving {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: hour))!
        return Craving(date: date, intensity: 3, trigger: trigger, didResist: resisted)
    }

    @Test("By-trigger breakdown counts totals and resisted, skipping empty triggers")
    func byTrigger() {
        let cravings = [
            craving(.stress, hour: 9, resisted: true),
            craving(.stress, hour: 10, resisted: false),
            craving(.coffee, hour: 8, resisted: true)
        ]
        let breakdown = analyzer.breakdownByTrigger(cravings)
        #expect(breakdown.count == 2)

        let stress = breakdown.first { $0.trigger == .stress }
        #expect(stress?.total == 2)
        #expect(stress?.resisted == 1)
        #expect(stress?.gaveIn == 1)
    }

    @Test("By-hour breakdown buckets cravings and stays sorted")
    func byHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let cravings = [
            craving(.stress, hour: 9, resisted: true),
            craving(.coffee, hour: 9, resisted: false),
            craving(.boredom, hour: 21, resisted: true)
        ]
        let byHour = analyzer.cravingsByHour(cravings, calendar: calendar)
        #expect(byHour == [HourlyCravings(hour: 9, count: 2), HourlyCravings(hour: 21, count: 1)])
    }

    @Test("Empty input yields empty breakdowns")
    func empty() {
        #expect(analyzer.breakdownByTrigger([]).isEmpty)
        #expect(analyzer.cravingsByHour([]).isEmpty)
    }
}
