import Foundation
import SwiftData

/// Builds the SwiftData container used across the app and its App Intents,
/// stored in the shared App Group so every process sees the same data.
enum SharedContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            return try! ModelContainer(
                for: CravingEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        // Prefer the shared App Group container so the widget reads the same
        // store as the app. This only succeeds when the App Group capability
        // is configured for the signing team (see README).
        let shared = ModelConfiguration("Breathe", groupContainer: .identifier(PlanStore.appGroup))
        if let container = try? ModelContainer(for: CravingEntity.self, configurations: shared) {
            return container
        }

        // Fall back to a local store so the app still runs out of the box,
        // before any App Group is set up. The widget simply shows its empty
        // state until sharing is enabled.
        return try! ModelContainer(for: CravingEntity.self)
    }
}
