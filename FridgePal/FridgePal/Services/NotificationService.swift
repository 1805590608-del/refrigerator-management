import Foundation
import UserNotifications

// MARK: - Notification Service

final class NotificationService {
    static let shared = NotificationService()
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

    /// Schedules expiration reminders for a FoodItem.
    /// Advance days come from user settings (default 1, 3, 7).
    func scheduleReminders(for item: FoodItem, advanceDays: [Int]) {
        guard let expDate = item.expirationDate, item.isActive else { return }

        cancelReminders(for: item)

        for days in advanceDays {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: expDate),
                  triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("notification.title", comment: "")
            let bodyFormat = NSLocalizedString("notification.body.format", comment: "")
            content.body = String(format: bodyFormat, item.name, days)
            content.sound = .default
            content.userInfo = ["foodItemId": item.id.uuidString]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = notificationId(for: item, days: days)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error { print("Notification error: \(error)") }
            }
        }
    }

    /// Cancels all possible reminder identifiers for the given item.
    /// Pass the same `advanceDays` that were used when scheduling so every
    /// pending identifier is removed.  Falls back to `[1, 3, 7]` when the
    /// caller does not supply a specific list.
    func cancelReminders(for item: FoodItem, advanceDays: [Int] = [1, 3, 7]) {
        let ids = advanceDays.map { notificationId(for: item, days: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func rescheduleAll(items: [FoodItem], advanceDays: [Int]) {
        center.removeAllPendingNotificationRequests()
        for item in items where item.isActive {
            scheduleReminders(for: item, advanceDays: advanceDays)
        }
    }

    // MARK: - Private

    private func notificationId(for item: FoodItem, days: Int) -> String {
        "fridge_\(item.id.uuidString)_\(days)d"
    }
}
