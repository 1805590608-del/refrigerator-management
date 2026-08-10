import Foundation
import SwiftData

/// Represents a consumed/discarded/expired food record for history tracking.
@Model
final class HistoryRecord {
    var id: UUID = UUID()
    var foodName: String = ""
    var category: String = FoodCategory.other.rawValue
    var storageLocation: String = StorageLocation.fridge.rawValue
    var quantity: Double = 1
    var unit: String = "item"
    var purchaseDate: Date = Date()
    var expirationDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String = ""
    var finalStatus: String = FoodStatus.expired.rawValue
    var archivedAt: Date = Date()
    var createdAt: Date = Date()

    init(from item: FoodItem, finalStatus: FoodStatus) {
        self.id = UUID()
        self.foodName = item.name
        self.category = item.category
        self.storageLocation = item.storageLocation
        self.quantity = item.quantity
        self.unit = item.unit
        self.purchaseDate = item.purchaseDate
        self.expirationDate = item.expirationDate
        self.photoData = item.photoData
        self.notes = item.notes
        self.finalStatus = finalStatus.rawValue
        self.archivedAt = Date()
        self.createdAt = item.createdAt
    }

    var finalStatusEnum: FoodStatus {
        FoodStatus(rawValue: finalStatus) ?? .expired
    }

    var categoryEnum: FoodCategory {
        FoodCategory(rawValue: category) ?? .other
    }
}
