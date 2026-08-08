import Foundation
import UserNotifications

// MARK: - Notification Service

final class NotificationService {
    static let shared = NotificationService()
    static let threadIdentifier = "fridgepal.expiration"

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// Rebuilds the complete pending reminder schedule from the active inventory.
    ///
    /// Reminders are planned as a whole (instead of per item) so that reminders
    /// landing on the same day can be merged into a single digest, and so the
    /// app stays within the system limit on pending local notifications.
    func refreshSchedule(for items: [FoodItem], settings: ReminderSettings = .current()) {
        let candidates = items.compactMap(Self.candidate(for:))
        let reminders = ReminderPlanner.plan(candidates: candidates, settings: settings)

        center.removeAllPendingNotificationRequests()

        for reminder in reminders {
            center.add(request(for: reminder)) { error in
                if let error { print("Notification error: \(error)") }
            }
        }
    }

    /// Convenience overload that reads the active inventory from a repository.
    func refreshSchedule(using repository: FoodRepositoryProtocol, settings: ReminderSettings = .current()) {
        let items = (try? repository.fetchActive()) ?? []
        refreshSchedule(for: items, settings: settings)
    }

    // MARK: - Private

    private static func candidate(for item: FoodItem) -> ReminderCandidate? {
        guard item.isActive, let expirationDate = item.expirationDate else { return nil }
        return ReminderCandidate(id: item.id, name: item.name, expirationDate: expirationDate)
    }

    private func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = Self.threadIdentifier
        content.userInfo = ["foodItemIds": reminder.itemIDs.map(\.uuidString)]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }
}
