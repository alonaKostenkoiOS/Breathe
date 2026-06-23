import Foundation
import SwiftData
import BreatheCore

/// SwiftData persistence model for a logged craving. Kept separate from the
/// domain ``Craving`` struct so the storage schema can evolve independently
/// of the pure domain type.
@Model
final class CravingEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var intensity: Int
    var triggerRaw: String
    var didResist: Bool
    var note: String?

    init(id: UUID, date: Date, intensity: Int, triggerRaw: String, didResist: Bool, note: String?) {
        self.id = id
        self.date = date
        self.intensity = intensity
        self.triggerRaw = triggerRaw
        self.didResist = didResist
        self.note = note
    }

    convenience init(_ craving: Craving) {
        self.init(
            id: craving.id,
            date: craving.date,
            intensity: craving.intensity,
            triggerRaw: craving.trigger.rawValue,
            didResist: craving.didResist,
            note: craving.note
        )
    }

    var domain: Craving {
        Craving(
            id: id,
            date: date,
            intensity: intensity,
            trigger: Craving.Trigger(rawValue: triggerRaw) ?? .other,
            didResist: didResist,
            note: note
        )
    }
}

/// Adapts SwiftData to the domain's ``CravingStoring`` protocol. The
/// `ModelActor` macro gives us a serialised actor with its own context, so
/// reads and writes are concurrency-safe.
@ModelActor
actor SwiftDataCravingStore: CravingStoring {
    func all() throws -> [Craving] {
        let descriptor = FetchDescriptor<CravingEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    func add(_ craving: Craving) throws {
        modelContext.insert(CravingEntity(craving))
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        try modelContext.delete(model: CravingEntity.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }
}
