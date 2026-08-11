import Foundation
import SwiftData

/// A standalone snapshot of an inventory or history item to repurchase.
@Model
final class ShoppingItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = FoodCategory.other.rawValue
    var preferredQuantity: Double = 1
    var unit: String = "item"
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory = .other,
        preferredQuantity: Double = 1,
        unit: String = "item",
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category.rawValue
        self.preferredQuantity = preferredQuantity
        self.unit = unit
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    init(from item: FoodItem) {
        let now = Date()
        self.id = UUID()
        self.name = item.name
        self.category = item.category
        self.preferredQuantity = item.quantity
        self.unit = item.unit
        self.isCompleted = false
        self.createdAt = now
        self.completedAt = nil
        self.updatedAt = now
    }

    init(from record: HistoryRecord) {
        let now = Date()
        self.id = UUID()
        self.name = record.foodName
        self.category = record.category
        self.preferredQuantity = record.quantity
        self.unit = record.unit
        self.isCompleted = false
        self.createdAt = now
        self.completedAt = nil
        self.updatedAt = now
    }

    var categoryEnum: FoodCategory {
        get { FoodCategory(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }

    func setCompleted(_ completed: Bool, at date: Date = Date()) {
        isCompleted = completed
        completedAt = completed ? date : nil
        updatedAt = date
    }
}

struct ShoppingItemSnapshot {
    let id: UUID
    let name: String
    let category: FoodCategory
    let preferredQuantity: Double
    let unit: String
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?
    let updatedAt: Date

    init(item: ShoppingItem) {
        id = item.id
        name = item.name
        category = item.categoryEnum
        preferredQuantity = item.preferredQuantity
        unit = item.unit
        isCompleted = item.isCompleted
        createdAt = item.createdAt
        completedAt = item.completedAt
        updatedAt = item.updatedAt
    }

    func makeItem() -> ShoppingItem {
        ShoppingItem(
            id: id,
            name: name,
            category: category,
            preferredQuantity: preferredQuantity,
            unit: unit,
            isCompleted: isCompleted,
            createdAt: createdAt,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
    }
}
