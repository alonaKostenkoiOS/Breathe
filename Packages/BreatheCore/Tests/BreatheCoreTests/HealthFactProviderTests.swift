import Foundation
import Testing
@testable import BreatheCore

@Suite("RemoteHealthFactProvider")
struct HealthFactProviderTests {
    /// Configurable network double.
    private struct StubFetcher: DataFetching {
        let result: Result<Data, Error>
        func data(from url: URL) async throws -> Data {
            try result.get()
        }
    }

    private let endpoint = URL(string: "https://example.com/facts.json")!

    private func gregorianDay(_ string: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }

    @Test("Valid JSON is decoded and a fact is returned")
    func decodesRemote() async {
        let facts = [HealthFact(id: "1", text: "one"), HealthFact(id: "2", text: "two")]
        let data = try! JSONEncoder().encode(facts)
        let provider = RemoteHealthFactProvider(endpoint: endpoint, fetcher: StubFetcher(result: .success(data)))

        let fact = await provider.dailyFact(on: gregorianDay("2026-01-01T00:00:00Z"))
        #expect(facts.contains(fact))
    }

    @Test("A network failure falls back to bundled facts instead of throwing")
    func fallsBackOnError() async {
        let provider = RemoteHealthFactProvider(
            endpoint: endpoint,
            fetcher: StubFetcher(result: .failure(HealthFactError.badResponse))
        )
        let fact = await provider.dailyFact(on: gregorianDay("2026-01-01T00:00:00Z"))
        #expect(HealthFact.fallback.contains(fact))
    }

    @Test("Malformed JSON falls back rather than crashing")
    func fallsBackOnGarbage() async {
        let provider = RemoteHealthFactProvider(
            endpoint: endpoint,
            fetcher: StubFetcher(result: .success(Data("not json".utf8)))
        )
        let fact = await provider.dailyFact(on: gregorianDay("2026-01-01T00:00:00Z"))
        #expect(HealthFact.fallback.contains(fact))
    }

    @Test("The same day always selects the same fact")
    func deterministicPerDay() async {
        let provider = RemoteHealthFactProvider(
            endpoint: endpoint,
            fetcher: StubFetcher(result: .failure(HealthFactError.badResponse))
        )
        let day = gregorianDay("2026-06-23T09:00:00Z")
        let a = await provider.dailyFact(on: day)
        let b = await provider.dailyFact(on: day)
        #expect(a == b)
    }
}
