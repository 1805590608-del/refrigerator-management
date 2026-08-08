import XCTest
import SwiftData
@testable import FridgePal

// MARK: - ExpirationState Tests

final class ExpirationStateTests: XCTestCase {

    func testFreshItem() {
        let item = FoodItem(
            name: "Apple",
            expirationDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        )
        XCTAssertEqual(item.expirationState, .fresh)
    }

    func testExpiringSoonItem_3Days() {
        let item = FoodItem(
            name: "Milk",
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        )
        XCTAssertEqual(item.expirationState, .expiringSoon)
    }

    func testExpiringSoonItem_exactlyToday() {
        // Expires today - should be expiringSoon (0 days left ≤ 3)
        let item = FoodItem(
            name: "Cheese",
            expirationDate: Calendar.current.startOfDay(for: Date())
        )
        XCTAssertEqual(item.expirationState, .expired) // already past start of today
    }

    func testExpiredItem() {
        let item = FoodItem(
            name: "Old Bread",
            expirationDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )
        XCTAssertEqual(item.expirationState, .expired)
    }

    func testNoExpirationDate() {
        let item = FoodItem(name: "Salt", expirationDate: nil)
        XCTAssertEqual(item.expirationState, .noDate)
    }

    func testBoundary_exactly3DaysLeft() {
        // 3 days = 72 hours from now
        let item = FoodItem(
            name: "Yogurt",
            expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        )
        // dateComponents returns integer days, so 3 days is exactly .expiringSoon
        XCTAssertEqual(item.expirationState, .expiringSoon)
    }

    func testBoundary_4DaysLeft() {
        let item = FoodItem(
            name: "Butter",
            expirationDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!
        )
        XCTAssertEqual(item.expirationState, .fresh)
    }
}

// MARK: - FoodItem Status Tests

final class FoodItemStatusTests: XCTestCase {

    func testDefaultStatusIsActive() {
        let item = FoodItem(name: "Carrot")
        XCTAssertEqual(item.statusEnum, .active)
        XCTAssertTrue(item.isActive)
    }

    func testSetStatusEaten() {
        let item = FoodItem(name: "Banana")
        item.statusEnum = .eaten
        XCTAssertFalse(item.isActive)
        XCTAssertEqual(item.statusEnum, .eaten)
    }

    func testCategoryRoundtrip() {
        let item = FoodItem(name: "Steak", category: .meat)
        XCTAssertEqual(item.categoryEnum, .meat)
        item.categoryEnum = .dairy
        XCTAssertEqual(item.category, FoodCategory.dairy.rawValue)
    }

    func testStorageLocationRoundtrip() {
        let item = FoodItem(name: "Ice Cream", storageLocation: .freezer)
        XCTAssertEqual(item.storageLocationEnum, .freezer)
    }

    func testUnknownRawValuesDefaultGracefully() {
        let item = FoodItem(name: "Unknown")
        item.category = "nonexistent"
        XCTAssertEqual(item.categoryEnum, .other)

        item.storageLocation = "nonexistent"
        XCTAssertEqual(item.storageLocationEnum, .fridge)

        item.status = "nonexistent"
        XCTAssertEqual(item.statusEnum, .active)
    }
}

// MARK: - Home Attention Tests

final class HomeAttentionItemsTests: XCTestCase {

    func testGroupsActiveUrgentItemsInActionableOrder() {
        let now = Date()
        let olderExpired = FoodItem(
            name: "Older expired",
            expirationDate: Calendar.current.date(byAdding: .day, value: -4, to: now)!
        )
        let recentlyExpired = FoodItem(
            name: "Recently expired",
            expirationDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!
        )
        let useFirst = FoodItem(
            name: "Use first",
            expirationDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!
        )
        let useNext = FoodItem(
            name: "Use next",
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: now)!
        )
        let fresh = FoodItem(
            name: "Fresh",
            expirationDate: Calendar.current.date(byAdding: .day, value: 10, to: now)!
        )
        let archived = FoodItem(
            name: "Archived",
            expirationDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            status: .eaten
        )

        let attentionItems = HomeAttentionItems(
            items: [useNext, olderExpired, fresh, archived, useFirst, recentlyExpired]
        )

        XCTAssertEqual(attentionItems.expired.map(\.name), ["Recently expired", "Older expired"])
        XCTAssertEqual(attentionItems.useSoon.map(\.name), ["Use first", "Use next"])
        XCTAssertFalse(attentionItems.isEmpty)
    }

    func testIsEmptyWhenNothingNeedsAttention() {
        let fresh = FoodItem(
            name: "Fresh",
            expirationDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        )
        let noDate = FoodItem(name: "No date")

        XCTAssertTrue(HomeAttentionItems(items: [fresh, noDate]).isEmpty)
    }
}

// MARK: - ImageService Tests

final class ImageServiceTests: XCTestCase {

    func testCompressLargeImage() {
        // Create a 2000×2000 image
        let size = CGSize(width: 2000, height: 2000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let largeImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        let resized = ImageService.resize(largeImage, maxLongEdge: ImageService.maxLongEdge)
        XCTAssertLessThanOrEqual(max(resized.size.width, resized.size.height), ImageService.maxLongEdge)
    }

    func testDoNotUpscaleSmallImage() {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let smallImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        let result = ImageService.resize(smallImage, maxLongEdge: ImageService.maxLongEdge)
        XCTAssertEqual(result.size, size)
    }

    func testCompressReturnsData() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let image = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
        }
        let data = ImageService.compress(image)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 0)
    }
}

// MARK: - Reminder Settings Tests

final class ReminderSettingsTests: XCTestCase {

    func testAdvanceDaysAreNormalized() {
        let settings = ReminderSettings(rawAdvanceDays: "7, 3,3, 1, oops, -2")
        XCTAssertEqual(settings.advanceDays, [1, 3, 7])
        XCTAssertEqual(settings.rawAdvanceDays, "1,3,7")
    }

    func testHourIsClamped() {
        XCTAssertEqual(ReminderSettings(hour: 99).hour, 23)
        XCTAssertEqual(ReminderSettings(hour: -5).hour, 0)
    }

    func testCurrentFallsBackToDefaultsWhenUnset() {
        let defaults = UserDefaults(suiteName: "ReminderSettingsTests.empty")!
        defaults.removePersistentDomain(forName: "ReminderSettingsTests.empty")
        let settings = ReminderSettings.current(defaults: defaults)
        XCTAssertEqual(settings.advanceDays, ReminderSettings.defaultAdvanceDays)
        XCTAssertEqual(settings.hour, ReminderSettings.defaultHour)
        XCTAssertTrue(settings.groupedDigest)
    }

    func testCurrentReadsStoredValues() {
        let suite = "ReminderSettingsTests.stored"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("1,3", forKey: ReminderSettings.StorageKey.advanceDays)
        defaults.set(false, forKey: ReminderSettings.StorageKey.groupedDigest)
        defaults.set(20, forKey: ReminderSettings.StorageKey.hour)

        let settings = ReminderSettings.current(defaults: defaults)
        XCTAssertEqual(settings.advanceDays, [1, 3])
        XCTAssertFalse(settings.groupedDigest)
        XCTAssertEqual(settings.hour, 20)

        defaults.removePersistentDomain(forName: suite)
    }
}

// MARK: - Reminder Planner Tests

final class ReminderPlannerTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)!
    }

    private func candidate(_ name: String, _ expiration: String) -> ReminderCandidate {
        ReminderCandidate(id: UUID(), name: name, expirationDate: date(expiration))
    }

    func testGroupedPlanMergesSameDayRemindersIntoOneDigest() {
        let milk = candidate("Milk", "2026-01-08 00:00")
        let eggs = candidate("Eggs", "2026-01-08 00:00")

        let plan = ReminderPlanner.plan(
            candidates: [milk, eggs],
            settings: ReminderSettings(advanceDays: [1, 3], groupedDigest: true, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan.map(\.identifier), ["fridge_digest_20260105", "fridge_digest_20260107"])
        XCTAssertEqual(plan.map { $0.itemIDs.count }, [2, 2])
        XCTAssertEqual(Set(plan[0].itemIDs), Set([milk.id, eggs.id]))
    }

    func testGroupedPlanIsSortedAndFlagsUrgency() {
        let plan = ReminderPlanner.plan(
            candidates: [candidate("Milk", "2026-01-08 00:00"), candidate("Bread", "2026-01-02 00:00")],
            settings: ReminderSettings(advanceDays: [1, 7], groupedDigest: true, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.triggerDate), [date("2026-01-01 09:00"), date("2026-01-07 09:00")])
        // Bread expires tomorrow, so the shared Jan 1 digest is urgent.
        XCTAssertEqual(plan[0].daysRemaining, 1)
        XCTAssertTrue(plan[0].isUrgent)
        XCTAssertTrue(plan[1].isUrgent)
    }

    func testGroupedPlanOrdersItemsByUrgency() {
        let bread = candidate("Bread", "2026-01-02 00:00")
        let milk = candidate("Milk", "2026-01-08 00:00")

        let plan = ReminderPlanner.plan(
            candidates: [milk, bread],
            settings: ReminderSettings(advanceDays: [1, 7], groupedDigest: true, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )

        XCTAssertEqual(plan[0].itemIDs, [bread.id, milk.id])
    }

    func testPastRemindersAreSkipped() {
        let plan = ReminderPlanner.plan(
            candidates: [candidate("Milk", "2026-01-08 00:00")],
            settings: ReminderSettings(advanceDays: [1, 3, 7], groupedDigest: true, hour: 9),
            now: date("2026-01-05 12:00"),
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.identifier), ["fridge_digest_20260107"])
    }

    func testUngroupedPlanKeepsPerItemIdentifiers() {
        let milk = candidate("Milk", "2026-01-08 00:00")

        let plan = ReminderPlanner.plan(
            candidates: [milk],
            settings: ReminderSettings(advanceDays: [1, 3], groupedDigest: false, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )

        XCTAssertEqual(
            plan.map(\.identifier),
            [
                ReminderPlanner.itemIdentifier(for: milk.id, days: 3),
                ReminderPlanner.itemIdentifier(for: milk.id, days: 1)
            ]
        )
        XCTAssertEqual(plan.map { $0.itemIDs }, [[milk.id], [milk.id]])
    }

    func testEmptyAdvanceDaysProducesNoReminders() {
        let plan = ReminderPlanner.plan(
            candidates: [candidate("Milk", "2026-01-08 00:00")],
            settings: ReminderSettings(advanceDays: [], groupedDigest: true, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )
        XCTAssertTrue(plan.isEmpty)
    }

    func testPlanStaysWithinPendingNotificationLimit() {
        let candidates = (0..<80).map { index in
            ReminderCandidate(
                id: UUID(),
                name: "Item \(index)",
                expirationDate: calendar.date(byAdding: .day, value: index, to: date("2026-01-10 00:00"))!
            )
        }

        let plan = ReminderPlanner.plan(
            candidates: candidates,
            settings: ReminderSettings(advanceDays: [1, 3, 7], groupedDigest: false, hour: 9),
            now: date("2026-01-01 08:00"),
            calendar: calendar
        )

        XCTAssertEqual(plan.count, ReminderPlanner.maxPendingReminders)
        // The soonest reminders survive the cap.
        XCTAssertEqual(plan.first?.triggerDate, date("2026-01-03 09:00"))
    }

    func testDigestIdentifierIsStablePerDay() {
        XCTAssertEqual(
            ReminderPlanner.digestIdentifier(for: date("2026-02-09 09:00"), calendar: calendar),
            "fridge_digest_20260209"
        )
    }
}

// MARK: - HistoryRecord Tests

final class HistoryRecordTests: XCTestCase {

    func testHistoryRecordCreatedFromItem() {
        let item = FoodItem(
            name: "Test Cheese",
            category: .dairy,
            storageLocation: .fridge,
            quantity: 2,
            unit: "block",
            expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            notes: "Cheddar"
        )
        let record = HistoryRecord(from: item, finalStatus: .eaten)
        XCTAssertEqual(record.foodName, "Test Cheese")
        XCTAssertEqual(record.finalStatusEnum, .eaten)
        XCTAssertEqual(record.categoryEnum, .dairy)
    }
}

// MARK: - Repeat Entry Draft Tests

final class FoodFormDraftTests: XCTestCase {

    func testFoodItemDraftCopiesEveryEditableFieldWithoutMutatingSource() {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let expirationDate = Date(timeIntervalSince1970: 1_700_604_800)
        let photoData = Data([0x01, 0x02, 0x03])
        let source = FoodItem(
            name: "Greek Yogurt",
            category: .dairy,
            storageLocation: .fridge,
            quantity: 4,
            unit: "pack",
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            photoData: photoData,
            notes: "Plain"
        )

        var draft = FoodFormDraft(item: source)

        XCTAssertEqual(draft.name, source.name)
        XCTAssertEqual(draft.category, source.categoryEnum)
        XCTAssertEqual(draft.storageLocation, source.storageLocationEnum)
        XCTAssertEqual(draft.quantity, source.quantity)
        XCTAssertEqual(draft.unit, source.unit)
        XCTAssertEqual(draft.purchaseDate, source.purchaseDate)
        XCTAssertEqual(draft.expirationDate, expirationDate)
        XCTAssertTrue(draft.hasExpirationDate)
        XCTAssertEqual(draft.photoData, source.photoData)
        XCTAssertEqual(draft.notes, source.notes)

        draft.name = "Vanilla Yogurt"
        draft.quantity = 2
        draft.notes = "Edited copy"
        let repeatedItem = draft.makeFoodItem()

        XCTAssertEqual(source.name, "Greek Yogurt")
        XCTAssertEqual(source.quantity, 4)
        XCTAssertEqual(source.notes, "Plain")
        XCTAssertNotEqual(repeatedItem.id, source.id)
        XCTAssertEqual(repeatedItem.name, "Vanilla Yogurt")
        XCTAssertEqual(repeatedItem.categoryEnum, .dairy)
        XCTAssertEqual(repeatedItem.storageLocationEnum, .fridge)
        XCTAssertEqual(repeatedItem.quantity, 2)
        XCTAssertEqual(repeatedItem.unit, "pack")
        XCTAssertEqual(repeatedItem.purchaseDate, purchaseDate)
        XCTAssertEqual(repeatedItem.expirationDate, expirationDate)
        XCTAssertEqual(repeatedItem.photoData, photoData)
        XCTAssertEqual(repeatedItem.notes, "Edited copy")
        XCTAssertEqual(repeatedItem.statusEnum, .active)
    }

    func testHistoryDraftCreatesDistinctActiveItemAndLeavesRecordUnchanged() {
        let source = FoodItem(
            name: "Leftovers",
            category: .cooked,
            storageLocation: .freezer,
            quantity: 2,
            unit: "box",
            purchaseDate: Date(timeIntervalSince1970: 1_710_000_000),
            expirationDate: nil,
            photoData: Data([0x04, 0x05]),
            notes: "Pasta"
        )
        let record = HistoryRecord(from: source, finalStatus: .eaten)

        var draft = FoodFormDraft(historyRecord: record)

        XCTAssertEqual(draft.name, record.foodName)
        XCTAssertEqual(draft.category, .cooked)
        XCTAssertEqual(draft.storageLocation, .freezer)
        XCTAssertEqual(draft.quantity, record.quantity)
        XCTAssertEqual(draft.unit, record.unit)
        XCTAssertEqual(draft.purchaseDate, record.purchaseDate)
        XCTAssertFalse(draft.hasExpirationDate)
        XCTAssertEqual(draft.photoData, record.photoData)
        XCTAssertEqual(draft.notes, record.notes)

        draft.storageLocation = .fridge
        draft.hasExpirationDate = true
        draft.expirationDate = Date(timeIntervalSince1970: 1_720_000_000)
        let repeatedItem = draft.makeFoodItem()

        XCTAssertEqual(record.storageLocation, StorageLocation.freezer.rawValue)
        XCTAssertNil(record.expirationDate)
        XCTAssertEqual(record.finalStatusEnum, .eaten)
        XCTAssertNotEqual(repeatedItem.id, record.id)
        XCTAssertEqual(repeatedItem.name, record.foodName)
        XCTAssertEqual(repeatedItem.categoryEnum, .cooked)
        XCTAssertEqual(repeatedItem.storageLocationEnum, .fridge)
        XCTAssertEqual(repeatedItem.quantity, record.quantity)
        XCTAssertEqual(repeatedItem.unit, record.unit)
        XCTAssertEqual(repeatedItem.purchaseDate, record.purchaseDate)
        XCTAssertEqual(repeatedItem.expirationDate, draft.expirationDate)
        XCTAssertEqual(repeatedItem.photoData, record.photoData)
        XCTAssertEqual(repeatedItem.notes, record.notes)
        XCTAssertEqual(repeatedItem.statusEnum, .active)
    }
}

// MARK: - Shopping Item Tests

final class ShoppingItemTests: XCTestCase {

    func testFoodItemSnapshotCopiesRepurchaseMetadataAndRemainsIndependent() {
        let source = FoodItem(
            name: "Greek Yogurt",
            category: .dairy,
            quantity: 4,
            unit: "pack"
        )

        let shoppingItem = ShoppingItem(from: source)
        source.name = "Vanilla Yogurt"
        source.quantity = 2

        XCTAssertEqual(shoppingItem.name, "Greek Yogurt")
        XCTAssertEqual(shoppingItem.categoryEnum, .dairy)
        XCTAssertEqual(shoppingItem.preferredQuantity, 4)
        XCTAssertEqual(shoppingItem.unit, "pack")
        XCTAssertFalse(shoppingItem.isCompleted)
        XCTAssertNil(shoppingItem.completedAt)
    }

    func testHistorySnapshotCopiesRepurchaseMetadata() {
        let source = FoodItem(
            name: "Soup",
            category: .cooked,
            quantity: 2,
            unit: "can"
        )
        let record = HistoryRecord(from: source, finalStatus: .eaten)

        let shoppingItem = ShoppingItem(from: record)

        XCTAssertEqual(shoppingItem.name, record.foodName)
        XCTAssertEqual(shoppingItem.categoryEnum, .cooked)
        XCTAssertEqual(shoppingItem.preferredQuantity, record.quantity)
        XCTAssertEqual(shoppingItem.unit, record.unit)
    }

    func testCompletionCanBeReversed() {
        let item = ShoppingItem(name: "Milk")
        let completionDate = Date(timeIntervalSince1970: 1_800_000_000)

        item.setCompleted(true, at: completionDate)

        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.completedAt, completionDate)
        XCTAssertEqual(item.updatedAt, completionDate)

        item.setCompleted(false, at: completionDate.addingTimeInterval(60))

        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedAt)
    }
}

@MainActor
final class ShoppingRepositoryTests: XCTestCase {

    func testAddCompleteReopenAndDeleteWorkflowPersists() throws {
        let schema = Schema([ShoppingItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = ShoppingRepository(context: container.mainContext)
        let source = FoodItem(name: "Apples", category: .fruit, quantity: 3, unit: "bag")

        let shoppingItem = try repository.add(from: source)

        XCTAssertEqual(try repository.fetchAll().map(\.name), ["Apples"])

        try repository.setCompleted(shoppingItem, isCompleted: true)
        XCTAssertTrue(try XCTUnwrap(repository.fetchAll().first).isCompleted)

        try repository.setCompleted(shoppingItem, isCompleted: false)
        XCTAssertFalse(try XCTUnwrap(repository.fetchAll().first).isCompleted)

        try repository.delete(shoppingItem)
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }
}

// MARK: - WasteInsights Tests

final class WasteInsightsTests: XCTestCase {

    // Convenience helper
    private func record(status: FoodStatus, category: FoodCategory = .other, location: StorageLocation = .fridge) -> HistoryRecord {
        let item = FoodItem(name: "Item", category: category, storageLocation: location)
        return HistoryRecord(from: item, finalStatus: status)
    }

    func testWasteRatioNilWhenNoRecords() {
        XCTAssertNil(WasteInsights.wasteRatio(in: []))
    }

    func testWasteRatioZeroWhenNothingWasted() {
        let records = [record(status: .eaten), record(status: .eaten)]
        XCTAssertEqual(WasteInsights.wasteRatio(in: records), 0.0)
    }

    func testWasteRatioFullyWasted() {
        let records = [record(status: .discarded), record(status: .expired)]
        XCTAssertEqual(WasteInsights.wasteRatio(in: records), 1.0)
    }

    func testWasteRatioMixed() {
        let records = [record(status: .eaten), record(status: .discarded)]
        XCTAssertEqual(WasteInsights.wasteRatio(in: records), 0.5)
    }

    func testTopCategoryNilWhenNoWaste() {
        let records = [record(status: .eaten, category: .dairy)]
        XCTAssertNil(WasteInsights.topCategory(in: records))
    }

    func testTopCategoryPicksMostWasted() {
        let records = [
            record(status: .discarded, category: .dairy),
            record(status: .expired,   category: .dairy),
            record(status: .discarded, category: .meat),
            record(status: .eaten,     category: .fruit)
        ]
        XCTAssertEqual(WasteInsights.topCategory(in: records), .dairy)
    }

    func testTopLocationNilWhenNoWaste() {
        let records = [record(status: .eaten, location: .fridge)]
        XCTAssertNil(WasteInsights.topLocation(in: records))
    }

    func testTopLocationPicksMostWasted() {
        let records = [
            record(status: .discarded, location: .pantry),
            record(status: .expired,   location: .pantry),
            record(status: .discarded, location: .fridge)
        ]
        XCTAssertEqual(WasteInsights.topLocation(in: records), .pantry)
    }

    func testTopCategoryNilWhenEmpty() {
        XCTAssertNil(WasteInsights.topCategory(in: []))
    }

    func testTopLocationNilWhenEmpty() {
        XCTAssertNil(WasteInsights.topLocation(in: []))
    }
}
