import Foundation
import Testing
@testable import BreatheCore

@Suite("InMemoryCravingStore")
struct CravingStoreTests {
    @Test("Cravings round-trip and come back newest-first")
    func addAndList() async throws {
        let store = InMemoryCravingStore()
        let older = Craving(date: Date(timeIntervalSince1970: 100), intensity: 2, trigger: .coffee, didResist: true)
        let newer = Craving(date: Date(timeIntervalSince1970: 200), intensity: 4, trigger: .stress, didResist: false)

        try await store.add(older)
        try await store.add(newer)

        let all = try await store.all()
        #expect(all.map(\.id) == [newer.id, older.id])
    }

    @Test("Deleting by id removes the matching craving")
    func delete() async throws {
        let craving = Craving(date: .now, intensity: 3, trigger: .boredom, didResist: true)
        let store = InMemoryCravingStore([craving])

        try await store.delete(id: craving.id)
        let all = try await store.all()
        #expect(all.isEmpty)
    }
}

@Suite("ProgressFormatter")
struct ProgressFormatterTests {
    private let formatter = ProgressFormatter(locale: Locale(identifier: "en_US"))

    @Test("Durations collapse to the two most significant units")
    func duration() {
        #expect(formatter.duration(0) == "0m")
        #expect(formatter.duration(90 * 60) == "1h 30m")
        #expect(formatter.duration(86_400 + 4 * 3_600) == "1d 4h")
    }

    @Test("Money renders in the requested currency")
    func money() {
        #expect(formatter.money(Decimal(124.5), currencyCode: "USD") == "$124.50")
    }
}
