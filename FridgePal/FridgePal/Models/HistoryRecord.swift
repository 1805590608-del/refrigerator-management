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
    var barcode: String = ""
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
        self.barcode = item.barcode
        self.purchaseDate = item.purchaseDate
        self.expirationDate = item.expirationDate
        self.photoData = item.photoData
        self.notes = item.notes
        self.finalStatus = finalStatus.rawValue
        self.archivedAt = Date()
        self.createdAt = item.createdAt
    }

    init(
        id: UUID,
        foodName: String,
        category: FoodCategory,
        storageLocation: StorageLocation,
        quantity: Double,
        unit: String,
        barcode: String,
        purchaseDate: Date,
        expirationDate: Date?,
        photoData: Data?,
        notes: String,
        finalStatus: FoodStatus,
        archivedAt: Date,
        createdAt: Date
    ) {
        self.id = id
        self.foodName = foodName
        self.category = category.rawValue
        self.storageLocation = storageLocation.rawValue
        self.quantity = quantity
        self.unit = unit
        self.barcode = barcode
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.photoData = photoData
        self.notes = notes
        self.finalStatus = finalStatus.rawValue
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    var finalStatusEnum: FoodStatus {
        FoodStatus(rawValue: finalStatus) ?? .expired
    }

    var categoryEnum: FoodCategory {
        FoodCategory(rawValue: category) ?? .other
    }

    var storageLocationEnum: StorageLocation {
        StorageLocation(rawValue: storageLocation) ?? .fridge
    }
}

struct HistoryRecordSnapshot {
    let id: UUID
    let foodName: String
    let category: FoodCategory
    let storageLocation: StorageLocation
    let quantity: Double
    let unit: String
    let barcode: String
    let purchaseDate: Date
    let expirationDate: Date?
    let photoData: Data?
    let notes: String
    let finalStatus: FoodStatus
    let archivedAt: Date
    let createdAt: Date

    init(record: HistoryRecord) {
        id = record.id
        foodName = record.foodName
        category = record.categoryEnum
        storageLocation = record.storageLocationEnum
        quantity = record.quantity
        unit = record.unit
        barcode = record.barcode
        purchaseDate = record.purchaseDate
        expirationDate = record.expirationDate
        photoData = record.photoData
        notes = record.notes
        finalStatus = record.finalStatusEnum
        archivedAt = record.archivedAt
        createdAt = record.createdAt
    }

    func makeRecord() -> HistoryRecord {
        HistoryRecord(
            id: id,
            foodName: foodName,
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            barcode: barcode,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            photoData: photoData,
            notes: notes,
            finalStatus: finalStatus,
            archivedAt: archivedAt,
            createdAt: createdAt
        )
    }
}
