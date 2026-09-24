# Breathe platform migration

## Existing architecture

- SwiftUI feature views use a single `AppEnvironment` composition root.
- `QuitPlan`, `QuitProfile`, and `SavingsGoal` are small Codable values in the
  App Group defaults; legacy keys are stable.
- `CravingEntity` is the sole SwiftData schema. `Craving` is its domain value.
- Coach sessions use an atomic local JSON file.
- Navigation is a four-tab `TabView`; layout tokens come from `BreatheScreen`.
- The app and widget share a String Catalog and language preference.

## Nicotine assumptions found

The previous root route required a quit profile. Home calculations, milestones,
history outcomes, notification scheduling, widgets, App Intents, and Settings
all used cigarette/smoke-free terminology. Those types remain the typed
nicotine payload; they are not reused for other programs.

## Non-destructive migration

`RecoveryPlatformState` is a versioned Codable envelope stored under
`recovery_platform_state_v1`. On first launch with any legacy quit plan/profile,
one active `nicotine` program is created and selected. Existing defaults and the
SwiftData store are neither rewritten nor deleted. The old identifiers,
currency, dates, goals, preferences, craving rows, and Coach sessions therefore
remain intact.

The new envelope contains program-scoped urges, behaviors, plans, risk windows,
strategy observations, Pause List items, safety acknowledgements, and privacy
settings. Deleting one program filters only rows with that program instance ID.

## Safety boundary

Alcohol and Gambling cannot reach their program UI before the shared safety
gate is acknowledged. Rules are deterministic and offline. They do not diagnose
or prescribe. Emergency and professional resources are never paywalled.

Safety copy, country resource coverage, alcohol screening thresholds, and
gambling crisis language require professional and native-translator review
before a production health release.
