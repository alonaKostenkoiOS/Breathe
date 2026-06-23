import Foundation
import Testing
@testable import BreatheCore

@Suite("ProgressCalculator")
struct ProgressCalculatorTests {
    private let calculator = ProgressCalculator()

    /// A plan: quit at epoch, 20/day, $10 a pack of 20 → $0.50 a cigarette.
    private func plan(quit: Date = Date(timeIntervalSince1970: 0)) -> QuitPlan {
        QuitPlan(
            quitDate: quit,
            cigarettesPerDay: 20,
            cigarettesPerPack: 20,
            pricePerPack: 10,
            currencyCode: "USD",
            minutesOfLifePerCigarette: 11
        )
    }

    @Test("Exactly one day smoke-free avoids a full day of cigarettes")
    func oneDay() {
        let p = plan()
        let result = calculator.progress(for: p, at: Date(timeIntervalSince1970: 86_400))

        #expect(result.cigarettesAvoided == 20)
        #expect(result.moneySaved == Decimal(10)) // 20 * $0.50
        #expect(result.daysSmokeFree == 1)
        #expect(result.lifeRegained == 20 * 11 * 60)
    }

    @Test("Cigarettes accrue continuously and floor to a whole count")
    func partialDay() {
        let p = plan()
        // Half a day → 10 cigarettes.
        let result = calculator.progress(for: p, at: Date(timeIntervalSince1970: 43_200))
        #expect(result.cigarettesAvoided == 10)
        #expect(result.moneySaved == Decimal(5))
    }

    @Test("A reference before the quit date never goes negative")
    func beforeQuit() {
        let p = plan(quit: Date(timeIntervalSince1970: 1_000))
        let result = calculator.progress(for: p, at: Date(timeIntervalSince1970: 0))

        #expect(result.timeSmokeFree == 0)
        #expect(result.cigarettesAvoided == 0)
        #expect(result.moneySaved == 0)
    }

    @Test("Money uses exact decimal arithmetic, not floating point")
    func decimalPrecision() {
        // $0.30 a cigarette is unrepresentable in binary floating point.
        let p = QuitPlan(
            quitDate: Date(timeIntervalSince1970: 0),
            cigarettesPerDay: 10,
            cigarettesPerPack: 10,
            pricePerPack: 3, // $0.30 each
            currencyCode: "USD"
        )
        let result = calculator.progress(for: p, at: Date(timeIntervalSince1970: 86_400))
        #expect(result.cigarettesAvoided == 10)
        #expect(result.moneySaved == Decimal(3)) // exactly $3.00
    }
}
