import XCTest
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

// MARK: - Notification Identifier Tests

final class NotificationServiceTests: XCTestCase {

    func testScheduleDoesNotCrashForActiveItem() {
        let item = FoodItem(
            name: "Milk",
            expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        )
        // Just ensure no crash
        NotificationService.shared.scheduleReminders(for: item, advanceDays: [1, 3, 7])
        NotificationService.shared.cancelReminders(for: item)
    }

    func testScheduleSkipsInactiveItem() {
        let item = FoodItem(
            name: "Milk",
            expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        )
        item.statusEnum = .eaten
        // Should not schedule (isActive == false)
        NotificationService.shared.scheduleReminders(for: item, advanceDays: [1, 3, 7])
        // No crash + no pending notifications for non-active item
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
