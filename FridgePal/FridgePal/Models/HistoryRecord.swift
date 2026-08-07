import Foundation
import SwiftData

/// Represents a consumed/discarded/expired food record for history tracking.
@Model
final class HistoryRecord {
    @Attribute(.unique) var id: UUID
    var foodName: String
    var category: String
    var storageLocation: String
    var quantity: Double
    var unit: String
    var purchaseDate: Date
    var expirationDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String
    var finalStatus: String        // eaten | discarded | expired
    var archivedAt: Date
    var createdAt: Date

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
