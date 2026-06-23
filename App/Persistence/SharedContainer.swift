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
        // store as the app — but ONLY when the group is actually entitled.
        // SwiftData fatal-errors (it does not throw) if asked for a group
        // container that isn't in the entitlements, so we must check first
        // rather than rely on try?.
        let group = PlanStore.appGroup
        let isEntitled = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group) != nil

        if isEntitled,
           let container = try? ModelContainer(
               for: CravingEntity.self,
               configurations: ModelConfiguration("Breathe", groupContainer: .identifier(group))
           ) {
            return container
        }

        // Fall back to a local store so the app always runs out of the box,
        // before any App Group is set up. The widget simply shows its empty
        // state until sharing is enabled.
        return try! ModelContainer(for: CravingEntity.self)
    }
}
