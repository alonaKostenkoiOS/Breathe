import Foundation
import Testing
import BreatheCore
@testable import Breathe

@Suite("Craving Coach local persistence")
struct CoachSessionStoreTests {
    @Test("Sessions survive store recreation and updates replace by ID")
    func roundTripAndReplace() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BreatheCoachTests-(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("sessions.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = UUID()
        var session = CoachSession(id: id, startedAt: Date(timeIntervalSince1970: 100),
                                   entryPoint: .home, trigger: .stress,
                                   initialIntensity: 5, selectedStrategyID: .calmBreathing)
        try await LocalCoachSessionStore(fileURL: url).save(session)

        session.outcome = .improved
        session.finalIntensity = 2
        try await LocalCoachSessionStore(fileURL: url).save(session)
        let restored = try await LocalCoachSessionStore(fileURL: url).all()

        #expect(restored.count == 1)
        #expect(restored.first?.id == id)
        #expect(restored.first?.outcome == .improved)
        #expect(restored.first?.finalIntensity == 2)
    }
}
