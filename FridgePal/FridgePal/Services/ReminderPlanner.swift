import Foundation

// MARK: - Reminder Settings

/// User-configurable reminder preferences, mirrored from the `@AppStorage` keys
/// written by the Settings screen.
struct ReminderSettings: Equatable {
    enum StorageKey {
        static let advanceDays = "reminderDays"
        static let groupedDigest = "reminderGroupedDigest"
        static let hour = "reminderHour"
    }

    static let defaultAdvanceDays = [1, 3, 7]
    static let defaultHour = 9

    /// Days before expiration a reminder should fire, ascending and deduplicated.
    /// `0` means "on the expiration day itself".
    let advanceDays: [Int]
    /// When true, all reminders that fall on the same day are merged into one digest.
    let groupedDigest: Bool
    /// Hour of the day (0...23) reminders are delivered.
    let hour: Int

    init(
        advanceDays: [Int] = ReminderSettings.defaultAdvanceDays,
        groupedDigest: Bool = true,
        hour: Int = ReminderSettings.defaultHour
    ) {
        self.advanceDays = Set(advanceDays.filter { $0 >= 0 }).sorted()
        self.groupedDigest = groupedDigest
        self.hour = min(max(hour, 0), 23)
    }

    init(
        rawAdvanceDays: String,
        groupedDigest: Bool = true,
        hour: Int = ReminderSettings.defaultHour
    ) {
        self.init(
            advanceDays: ReminderSettings.parseAdvanceDays(rawAdvanceDays),
            groupedDigest: groupedDigest,
            hour: hour
        )
    }

    var rawAdvanceDays: String {
        advanceDays.map(String.init).joined(separator: ",")
    }

    static func parseAdvanceDays(_ raw: String) -> [Int] {
        raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Settings currently persisted by the Settings screen.
    static func current(defaults: UserDefaults = .standard) -> ReminderSettings {
        let raw = defaults.string(forKey: StorageKey.advanceDays)
            ?? defaultAdvanceDays.map(String.init).joined(separator: ",")
        let grouped = defaults.object(forKey: StorageKey.groupedDigest) as? Bool ?? true
        let hour = defaults.object(forKey: StorageKey.hour) as? Int ?? defaultHour
        return ReminderSettings(rawAdvanceDays: raw, groupedDigest: grouped, hour: hour)
    }
}

// MARK: - Reminder Candidate

/// Lightweight, storage-independent view of an item that can be reminded about.
struct ReminderCandidate: Equatable {
    let id: UUID
    let name: String
    let expirationDate: Date
}

// MARK: - Planned Reminder

/// A single notification the planner wants the system to deliver.
struct PlannedReminder: Equatable {
    let identifier: String
    let triggerDate: Date
    /// Items covered by this reminder, most urgent first.
    let itemIDs: [UUID]
    /// Days left for the most urgent item in this reminder.
    let daysRemaining: Int
    let title: String
    let body: String

    /// Reminders for items expiring today or tomorrow get urgent copy.
    var isUrgent: Bool { daysRemaining <= 1 }
}

// MARK: - Reminder Planner

/// Pure scheduling logic for expiration reminders.
///
/// Keeping the planning free of `UNUserNotificationCenter` makes the behaviour
/// (grouping, urgency, ordering, platform limits) unit-testable.
enum ReminderPlanner {
    /// iOS keeps at most 64 pending local notifications per app; stay below that
    /// so the soonest reminders are never dropped by the system.
    static let maxPendingReminders = 60

    /// Number of item names spelled out in a digest before "+N more" is used.
    static let maxNamesInDigest = 3

    private struct Occurrence {
        let candidate: ReminderCandidate
        let triggerDate: Date
        let daysRemaining: Int
    }

    static func plan(
        candidates: [ReminderCandidate],
        settings: ReminderSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        guard !settings.advanceDays.isEmpty else { return [] }

        var occurrences: [Occurrence] = []
        for candidate in candidates {
            let expirationDay = calendar.startOfDay(for: candidate.expirationDate)
            for days in settings.advanceDays {
                guard let reminderDay = calendar.date(byAdding: .day, value: -days, to: expirationDay),
                      let triggerDate = calendar.date(bySettingHour: settings.hour, minute: 0, second: 0, of: reminderDay),
                      triggerDate > now else { continue }
                occurrences.append(
                    Occurrence(candidate: candidate, triggerDate: triggerDate, daysRemaining: days)
                )
            }
        }

        let reminders = settings.groupedDigest
            ? groupedReminders(from: occurrences, calendar: calendar)
            : individualReminders(from: occurrences)

        let sorted = reminders.sorted { lhs, rhs in
            lhs.triggerDate == rhs.triggerDate
                ? lhs.identifier < rhs.identifier
                : lhs.triggerDate < rhs.triggerDate
        }
        return Array(sorted.prefix(maxPendingReminders))
    }

    // MARK: Identifiers

    static func digestIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "fridge_digest_%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func itemIdentifier(for id: UUID, days: Int) -> String {
        "fridge_\(id.uuidString)_\(days)d"
    }

    // MARK: Private

    private static func groupedReminders(from occurrences: [Occurrence], calendar: Calendar) -> [PlannedReminder] {
        let groups = Dictionary(grouping: occurrences) { digestIdentifier(for: $0.triggerDate, calendar: calendar) }
        return groups.compactMap { identifier, group -> PlannedReminder? in
            guard let triggerDate = group.first?.triggerDate else { return nil }
            let ordered = group.sorted { lhs, rhs in
                lhs.daysRemaining == rhs.daysRemaining
                    ? lhs.candidate.name.localizedCaseInsensitiveCompare(rhs.candidate.name) == .orderedAscending
                    : lhs.daysRemaining < rhs.daysRemaining
            }
            let daysRemaining = ordered.first?.daysRemaining ?? 0
            let names = ordered.map(\.candidate.name)
            return PlannedReminder(
                identifier: identifier,
                triggerDate: triggerDate,
                itemIDs: ordered.map(\.candidate.id),
                daysRemaining: daysRemaining,
                title: title(isUrgent: daysRemaining <= 1, isDigest: names.count > 1),
                body: names.count == 1
                    ? singleItemBody(name: names[0], daysRemaining: daysRemaining)
                    : digestBody(names: names, daysRemaining: daysRemaining)
            )
        }
    }

    private static func individualReminders(from occurrences: [Occurrence]) -> [PlannedReminder] {
        occurrences.map { occurrence in
            PlannedReminder(
                identifier: itemIdentifier(for: occurrence.candidate.id, days: occurrence.daysRemaining),
                triggerDate: occurrence.triggerDate,
                itemIDs: [occurrence.candidate.id],
                daysRemaining: occurrence.daysRemaining,
                title: title(isUrgent: occurrence.daysRemaining <= 1, isDigest: false),
                body: singleItemBody(name: occurrence.candidate.name, daysRemaining: occurrence.daysRemaining)
            )
        }
    }

    // MARK: Copy

    private static func title(isUrgent: Bool, isDigest: Bool) -> String {
        if isUrgent {
            return NSLocalizedString("notification.title.urgent", comment: "")
        }
        return NSLocalizedString(isDigest ? "notification.title.digest" : "notification.title", comment: "")
    }

    private static func singleItemBody(name: String, daysRemaining: Int) -> String {
        switch daysRemaining {
        case 0:
            return String(format: NSLocalizedString("notification.body.today.format", comment: ""), name)
        case 1:
            return String(format: NSLocalizedString("notification.body.tomorrow.format", comment: ""), name)
        default:
            return String(format: NSLocalizedString("notification.body.format", comment: ""), name, daysRemaining)
        }
    }

    private static func digestBody(names: [String], daysRemaining: Int) -> String {
        let key = daysRemaining <= 1
            ? "notification.body.digest.urgent.format"
            : "notification.body.digest.format"
        return String(format: NSLocalizedString(key, comment: ""), names.count, namesSummary(names))
    }

    private static func namesSummary(_ names: [String]) -> String {
        guard names.count > maxNamesInDigest else {
            return ListFormatter.localizedString(byJoining: names)
        }
        let listed = ListFormatter.localizedString(byJoining: Array(names.prefix(maxNamesInDigest)))
        return String(
            format: NSLocalizedString("notification.body.namesOverflow.format", comment: ""),
            listed,
            names.count - maxNamesInDigest
        )
    }
}
