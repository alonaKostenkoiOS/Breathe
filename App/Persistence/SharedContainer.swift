import Foundation
import SwiftData

/// Builds the SwiftData container used across the app and its App Intents,
/// stored in the shared App Group so every process sees the same data.
enum SharedContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                "Breathe",
                groupContainer: .identifier(PlanStore.appGroup)
            )
        }
        // A persistent store failure is unrecoverable at launch; surfacing it
        // loudly in development beats silently shipping a broken store.
        return try! ModelContainer(for: CravingEntity.self, configurations: configuration)
    }
}
