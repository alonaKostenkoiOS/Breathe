import Foundation
import UserNotifications
import BreatheCore

struct NotificationCopy: Equatable, Sendable {
    let title: String; let body: String
    static func make(title: String, body: String, discreet: Bool, language: AppLanguage) -> NotificationCopy {
        discreet
            ? NotificationCopy(title: AppLocalization.string("notification.discreet.title", language: language),
                               body: AppLocalization.string("notification.discreet.body", language: language))
            : NotificationCopy(title: title, body: body)
    }
}

/// Schedules the local notifications the app fires for upcoming health
/// milestones. Behind a protocol so view models can depend on the seam and
/// tests / previews can use a no-op double.
protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    @discardableResult func requestAuthorization() async -> Bool
    func scheduleMilestones(for plan: QuitPlan, using engine: MilestoneEngine, now: Date) async
    func cancelAll() async
}

/// `UserNotifications`-backed implementation. It fetches the shared center
/// inside each call rather than storing it, so the type stays `Sendable`
/// under Swift 6 strict concurrency.
struct LocalNotificationService: NotificationScheduling {
    private static let identifierPrefix = "milestone."

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Replaces any previously scheduled milestone notifications with one per
    /// not-yet-reached milestone, firing at the moment the body reaches it.
    func scheduleMilestones(for plan: QuitPlan, using engine: MilestoneEngine, now: Date) async {
        await cancelAll()

        let center = UNUserNotificationCenter.current()
        for status in engine.statuses(for: plan, at: now) where !status.isAchieved {
            let interval = status.reachedAt.timeIntervalSince(now)
            guard interval > 0 else { continue }

            let content = UNMutableNotificationContent()
            let language = AppLocalization.selectedLanguage()
            let title = AppLocalization.string(status.milestone.title, language: language)
            let detail = AppLocalization.string(status.milestone.detail, language: language)
            let discreet = (UserDefaults(suiteName: PlanStore.appGroup) ?? .standard).bool(forKey: "discreet_notifications")
            let copy = NotificationCopy.make(
                title: AppLocalization.string("Milestone reached 🫁", language: language),
                body: "\(title) — \(detail)", discreet: discreet, language: language)
            content.title = copy.title; content.body = copy.body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + status.milestone.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// No-op used in previews and seeded UI-test runs.
struct NoopNotificationService: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
    @discardableResult func requestAuthorization() async -> Bool { true }
    func scheduleMilestones(for plan: QuitPlan, using engine: MilestoneEngine, now: Date) async {}
    func cancelAll() async {}
}
