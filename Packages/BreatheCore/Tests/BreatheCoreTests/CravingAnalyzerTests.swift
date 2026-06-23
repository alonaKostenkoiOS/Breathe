import Foundation
import Testing
@testable import BreatheCore

@Suite("CravingAnalyzer")
struct CravingAnalyzerTests {
    private let analyzer = CravingAnalyzer()

    private func craving(_ trigger: Craving.Trigger, resisted: Bool) -> Craving {
        Craving(date: Date(timeIntervalSince1970: 0), intensity: 3, trigger: trigger, didResist: resisted)
    }

    @Test("Empty input yields the empty insights value")
    func empty() {
        #expect(analyzer.insights(from: []) == .empty)
    }

    @Test("Resistance rate is the share of resisted cravings")
    func resistanceRate() {
        let cravings = [
            craving(.stress, resisted: true),
            craving(.coffee, resisted: true),
            craving(.boredom, resisted: false),
            craving(.social, resisted: false)
        ]
        let insights = analyzer.insights(from: cravings)
        #expect(insights.total == 4)
        #expect(insights.resisted == 2)
        #expect(insights.resistanceRate == 0.5)
    }

    @Test("The most frequent trigger surfaces as the top trigger")
    func topTrigger() {
        let cravings = [
            craving(.stress, resisted: true),
            craving(.stress, resisted: false),
            craving(.coffee, resisted: true)
        ]
        #expect(analyzer.insights(from: cravings).topTrigger == .stress)
    }

    @Test("Intensity is clamped into the 1...5 range on construction")
    func intensityClamping() {
        #expect(Craving(date: .now, intensity: 99, trigger: .stress, didResist: true).intensity == 5)
        #expect(Craving(date: .now, intensity: -4, trigger: .stress, didResist: true).intensity == 1)
    }
}
