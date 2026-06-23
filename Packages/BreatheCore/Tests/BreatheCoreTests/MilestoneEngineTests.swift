import Foundation
import Testing
@testable import BreatheCore

@Suite("MilestoneEngine")
struct MilestoneEngineTests {
    private let testCatalogue: [HealthMilestone] = [
        HealthMilestone(id: "a", title: "A", detail: "", offset: 60, category: .heart),
        HealthMilestone(id: "b", title: "B", detail: "", offset: 3_600, category: .lungs),
        HealthMilestone(id: "c", title: "C", detail: "", offset: 86_400, category: .heart)
    ]

    private func plan() -> QuitPlan {
        QuitPlan(quitDate: Date(timeIntervalSince1970: 0), cigarettesPerDay: 20, pricePerPack: 10)
    }

    @Test("Milestones flip to achieved once their offset has elapsed")
    func achievement() {
        let engine = MilestoneEngine(catalogue: testCatalogue)
        // 90 seconds in: only the 60s milestone is reached.
        let statuses = engine.statuses(for: plan(), at: Date(timeIntervalSince1970: 90))

        #expect(statuses.count == 3)
        #expect(statuses[0].isAchieved)
        #expect(!statuses[1].isAchieved)
        #expect(!statuses[2].isAchieved)
    }

    @Test("Statuses are always returned in chronological order")
    func ordering() {
        let shuffled = [testCatalogue[2], testCatalogue[0], testCatalogue[1]]
        let engine = MilestoneEngine(catalogue: shuffled)
        let statuses = engine.statuses(for: plan(), at: Date(timeIntervalSince1970: 0))
        #expect(statuses.map(\.milestone.id) == ["a", "b", "c"])
    }

    @Test("The next milestone is the soonest unreached one")
    func next() {
        let engine = MilestoneEngine(catalogue: testCatalogue)
        let next = engine.nextMilestone(for: plan(), at: Date(timeIntervalSince1970: 90))
        #expect(next?.milestone.id == "b")
    }

    @Test("Fraction reports partial progress toward the next milestone")
    func fraction() {
        let engine = MilestoneEngine(catalogue: testCatalogue)
        // Halfway to the 3600s milestone.
        let statuses = engine.statuses(for: plan(), at: Date(timeIntervalSince1970: 1_800))
        #expect(statuses[1].fraction == 0.5)
        #expect(statuses[0].fraction == 1) // already achieved → clamped to 1
    }

    @Test("Achieved count grows monotonically with elapsed time")
    func achievedCount() {
        let engine = MilestoneEngine(catalogue: testCatalogue)
        #expect(engine.achievedCount(for: plan(), at: Date(timeIntervalSince1970: 0)) == 0)
        #expect(engine.achievedCount(for: plan(), at: Date(timeIntervalSince1970: 90)) == 1)
        #expect(engine.achievedCount(for: plan(), at: Date(timeIntervalSince1970: 200_000)) == 3)
    }

    @Test("The bundled catalogue is non-empty and ordered")
    func canonicalCatalogue() {
        let offsets = HealthMilestone.catalogue.map(\.offset)
        #expect(!offsets.isEmpty)
        #expect(offsets == offsets.sorted())
    }
}
