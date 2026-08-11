import Foundation
import SwiftData

protocol ShoppingRepositoryProtocol {
    func fetchAll() throws -> [ShoppingItem]
    @discardableResult func add(
        name: String,
        category: FoodCategory,
        preferredQuantity: Double,
        unit: String
    ) throws -> ShoppingItem
    @discardableResult func add(from item: FoodItem) throws -> ShoppingItem
    @discardableResult func add(from items: [FoodItem]) throws -> [ShoppingItem]
    @discardableResult func add(from record: HistoryRecord) throws -> ShoppingItem
    func setCompleted(_ item: ShoppingItem, isCompleted: Bool) throws
    func delete(_ item: ShoppingItem) throws
    func clearCompleted() throws
}

final class ShoppingRepository: ShoppingRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [ShoppingItem] {
        let descriptor = FetchDescriptor<ShoppingItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func add(
        name: String,
        category: FoodCategory,
        preferredQuantity: Double,
        unit: String
    ) throws -> ShoppingItem {
        var existingItems = try fetchAll()
        let shoppingItem = addOrMerge(
            name: name,
            category: category,
            preferredQuantity: preferredQuantity,
            unit: unit,
            existingItems: &existingItems
        )
        try context.save()
        return shoppingItem
    }

    @discardableResult
    func add(from item: FoodItem) throws -> ShoppingItem {
        try add(
            name: item.name,
            category: item.categoryEnum,
            preferredQuantity: item.quantity,
            unit: item.unit
        )
    }

    @discardableResult
    func add(from items: [FoodItem]) throws -> [ShoppingItem] {
        guard !items.isEmpty else { return [] }
        var existingItems = try fetchAll()
        let shoppingItems = items.map {
            addOrMerge(
                name: $0.name,
                category: $0.categoryEnum,
                preferredQuantity: $0.quantity,
                unit: $0.unit,
                existingItems: &existingItems
            )
        }
        try context.save()
        return shoppingItems
    }

    @discardableResult
    func add(from record: HistoryRecord) throws -> ShoppingItem {
        try add(
            name: record.foodName,
            category: record.categoryEnum,
            preferredQuantity: record.quantity,
            unit: record.unit
        )
    }

    func setCompleted(_ item: ShoppingItem, isCompleted: Bool) throws {
        item.setCompleted(isCompleted)
        try context.save()
    }

    func delete(_ item: ShoppingItem) throws {
        context.delete(item)
        try context.save()
    }

    func restore(_ snapshots: [ShoppingItemSnapshot]) throws {
        for snapshot in snapshots {
            context.insert(snapshot.makeItem())
        }
        try context.save()
    }

    func clearCompleted() throws {
        let completedItems = try fetchAll().filter(\.isCompleted)
        for item in completedItems {
            context.delete(item)
        }
        try context.save()
    }

    private func addOrMerge(
        name: String,
        category: FoodCategory,
        preferredQuantity: Double,
        unit: String,
        existingItems: inout [ShoppingItem]
    ) -> ShoppingItem {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if let existing = existingItems.first(where: {
            !$0.isCompleted &&
            $0.unit == unit &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) == normalizedName
        }) {
            existing.preferredQuantity += preferredQuantity
            if existing.categoryEnum == .other {
                existing.categoryEnum = category
            }
            existing.updatedAt = Date()
            return existing
        }

        let shoppingItem = ShoppingItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            preferredQuantity: preferredQuantity,
            unit: unit
        )
        context.insert(shoppingItem)
        existingItems.append(shoppingItem)
        return shoppingItem
    }
}
