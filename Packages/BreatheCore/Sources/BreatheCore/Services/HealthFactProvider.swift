import Foundation

/// Supplies the motivational health fact shown on the dashboard.
public protocol HealthFactProviding: Sendable {
    /// Returns a fact for the given day. Implementations must never throw to
    /// the caller for a transient network issue — the dashboard always shows
    /// *something* — so offline behaviour is part of the contract.
    func dailyFact(on day: Date) async -> HealthFact
}

/// Minimal seam over the network so the provider can be tested without
/// hitting a real server. `URLSession` conforms in an extension below.
public protocol DataFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

extension URLSession: DataFetching {
    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await data(from: url, delegate: nil)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw HealthFactError.badResponse
        }
        return data
    }
}

public enum HealthFactError: Error, Equatable {
    case badResponse
    case empty
}

/// Fetches a list of facts from a remote JSON endpoint and selects a stable
/// "fact of the day". Any failure falls back to bundled content, so the
/// caller always receives a usable fact.
public struct RemoteHealthFactProvider: HealthFactProviding {
    private let endpoint: URL
    private let fetcher: DataFetching
    private let calendar: Calendar
    private let fallback: [HealthFact]

    public init(
        endpoint: URL,
        fetcher: DataFetching,
        calendar: Calendar = .init(identifier: .gregorian),
        fallback: [HealthFact] = HealthFact.fallback
    ) {
        self.endpoint = endpoint
        self.fetcher = fetcher
        self.calendar = calendar
        self.fallback = fallback
    }

    public func dailyFact(on day: Date) async -> HealthFact {
        let pool = await loadFacts()
        return select(from: pool, on: day)
    }

    private func loadFacts() async -> [HealthFact] {
        do {
            let data = try await fetcher.data(from: endpoint)
            let facts = try JSONDecoder().decode([HealthFact].self, from: data)
            guard !facts.isEmpty else { return fallback }
            return facts
        } catch {
            return fallback
        }
    }

    /// Picks an element deterministically from the day-of-era, so the same
    /// day always yields the same fact and consecutive days rotate.
    private func select(from pool: [HealthFact], on day: Date) -> HealthFact {
        let safePool = pool.isEmpty ? fallback : pool
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        let index = abs(dayNumber) % safePool.count
        return safePool[index]
    }
}
