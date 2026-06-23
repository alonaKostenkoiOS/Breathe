import Foundation

/// Persistence boundary for cravings. The domain layer depends only on this
/// protocol; the app provides a SwiftData-backed implementation. This keeps
/// `BreatheCore` free of any storage framework and trivially testable with
/// an in-memory double.
public protocol CravingStoring: Sendable {
    func all() async throws -> [Craving]
    func add(_ craving: Craving) async throws
    func delete(id: UUID) async throws
}

/// In-memory store used by tests and SwiftUI previews.
public actor InMemoryCravingStore: CravingStoring {
    private var storage: [Craving]

    public init(_ seed: [Craving] = []) {
        self.storage = seed
    }

    public func all() async throws -> [Craving] {
        storage.sorted { $0.date > $1.date }
    }

    public func add(_ craving: Craving) async throws {
        storage.append(craving)
    }

    public func delete(id: UUID) async throws {
        storage.removeAll { $0.id == id }
    }
}
