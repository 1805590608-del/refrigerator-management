import Foundation
import SwiftData

protocol ShoppingRepositoryProtocol {
    func fetchAll() throws -> [ShoppingItem]
    @discardableResult func add(from item: FoodItem) throws -> ShoppingItem
    @discardableResult func add(from items: [FoodItem]) throws -> [ShoppingItem]
    @discardableResult func add(from record: HistoryRecord) throws -> ShoppingItem
    func setCompleted(_ item: ShoppingItem, isCompleted: Bool) throws
    func delete(_ item: ShoppingItem) throws
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
    func add(from item: FoodItem) throws -> ShoppingItem {
        let shoppingItem = ShoppingItem(from: item)
        context.insert(shoppingItem)
        try context.save()
        return shoppingItem
    }

    @discardableResult
    func add(from items: [FoodItem]) throws -> [ShoppingItem] {
        guard !items.isEmpty else { return [] }
        let shoppingItems = items.map { ShoppingItem(from: $0) }
        for shoppingItem in shoppingItems { context.insert(shoppingItem) }
        try context.save()
        return shoppingItems
    }

    @discardableResult
    func add(from record: HistoryRecord) throws -> ShoppingItem {
        let shoppingItem = ShoppingItem(from: record)
        context.insert(shoppingItem)
        try context.save()
        return shoppingItem
    }

    func setCompleted(_ item: ShoppingItem, isCompleted: Bool) throws {
        item.setCompleted(isCompleted)
        try context.save()
    }

    func delete(_ item: ShoppingItem) throws {
        context.delete(item)
        try context.save()
    }
}
