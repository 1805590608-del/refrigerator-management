import Foundation
import SwiftData

/// A standalone snapshot of an inventory or history item to repurchase.
@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var preferredQuantity: Double
    var unit: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var updatedAt: Date

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
