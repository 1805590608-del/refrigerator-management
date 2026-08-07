import Foundation
import SwiftUI
import SwiftData
import PhotosUI

struct FoodFormDraft {
    var name: String
    var category: FoodCategory
    var storageLocation: StorageLocation
    var quantity: Double
    var unit: String
    var purchaseDate: Date
    var expirationDate: Date
    var hasExpirationDate: Bool
    var photoData: Data?
    var notes: String

    init(
        name: String = "",
        category: FoodCategory = .other,
        storageLocation: StorageLocation = .fridge,
        quantity: Double = 1,
        unit: String = "item",
        purchaseDate: Date = Date(),
        expirationDate: Date = FoodFormDraft.defaultExpirationDate,
        hasExpirationDate: Bool = true,
        photoData: Data? = nil,
        notes: String = ""
    ) {
        self.name = name
        self.category = category
        self.storageLocation = storageLocation
        self.quantity = quantity
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.hasExpirationDate = hasExpirationDate
        self.photoData = photoData
        self.notes = notes
    }

    init(item: FoodItem) {
        self.init(
            name: item.name,
            category: item.categoryEnum,
            storageLocation: item.storageLocationEnum,
            quantity: item.quantity,
            unit: item.unit,
            purchaseDate: item.purchaseDate,
            expirationDate: item.expirationDate ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: item.expirationDate != nil,
            photoData: item.photoData,
            notes: item.notes
        )
    }

    init(historyRecord: HistoryRecord) {
        self.init(
            name: historyRecord.foodName,
            category: FoodCategory(rawValue: historyRecord.category) ?? .other,
            storageLocation: StorageLocation(rawValue: historyRecord.storageLocation) ?? .fridge,
            quantity: historyRecord.quantity,
            unit: historyRecord.unit,
            purchaseDate: historyRecord.purchaseDate,
            expirationDate: historyRecord.expirationDate ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: historyRecord.expirationDate != nil,
            photoData: historyRecord.photoData,
            notes: historyRecord.notes
        )
    }

    func makeFoodItem() -> FoodItem {
        FoodItem(
            name: name,
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            purchaseDate: purchaseDate,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            photoData: photoData,
            notes: notes
        )
    }

    func apply(to item: FoodItem) {
        item.name = name
        item.category = category.rawValue
        item.storageLocation = storageLocation.rawValue
        item.quantity = quantity
        item.unit = unit
        item.purchaseDate = purchaseDate
        item.expirationDate = hasExpirationDate ? expirationDate : nil
        item.photoData = photoData
        item.notes = notes
        item.updatedAt = Date()
    }

    private static var defaultExpirationDate: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }
}

@MainActor
final class AddEditFoodViewModel: ObservableObject {
    // Form fields
    @Published var name: String = ""
    @Published var category: FoodCategory = .other
    @Published var storageLocation: StorageLocation = .fridge
    @Published var quantity: Double = 1
    @Published var unit: String = "item"
    @Published var purchaseDate: Date = Date()
    @Published var expirationDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @Published var hasExpirationDate: Bool = true
    @Published var notes: String = ""
    @Published var selectedImage: UIImage? = nil
    @Published var photoData: Data? = nil

    // Validation
    @Published var nameError: String? = nil
    @Published var quantityError: String? = nil

    // State
    @Published var isSaving: Bool = false
    @Published var saveError: String? = nil

    let isEditing: Bool
    private let item: FoodItem?
    private let repository: FoodRepositoryProtocol?
    private let notificationService = NotificationService.shared

    init(
        item: FoodItem? = nil,
        prefill: FoodFormDraft? = nil,
        repository: FoodRepositoryProtocol? = nil
    ) {
        self.item = item
        self.repository = repository
        self.isEditing = item != nil

        if let draft = item.map(FoodFormDraft.init(item:)) ?? prefill {
            apply(draft)
        }
    }

    func setImage(_ image: UIImage) {
        selectedImage = image
        photoData = ImageService.compress(image)
    }

    func removeImage() {
        selectedImage = nil
        photoData = nil
    }

    func validate() -> Bool {
        var valid = true
        nameError = nil
        quantityError = nil

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            nameError = NSLocalizedString("validation.nameRequired", comment: "")
            valid = false
        }
        if quantity <= 0 {
            quantityError = NSLocalizedString("validation.quantityPositive", comment: "")
            valid = false
        }
        return valid
    }

    @discardableResult
    func save(advanceDays: [Int]) throws -> Bool {
        guard let repository else {
            throw SaveError.repositoryUnavailable
        }
        return try save(to: repository, advanceDays: advanceDays)
    }

    @discardableResult
    func save(to repository: FoodRepositoryProtocol, advanceDays: [Int]) throws -> Bool {
        guard validate() else { return false }

        isSaving = true
        defer { isSaving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        name = trimmedName
        let draft = currentDraft

        if let existingItem = item {
            draft.apply(to: existingItem)
            try repository.save(existingItem)
            notificationService.cancelReminders(for: existingItem, advanceDays: advanceDays)
            notificationService.scheduleReminders(for: existingItem, advanceDays: advanceDays)
        } else {
            let newItem = draft.makeFoodItem()
            try repository.save(newItem)
            notificationService.scheduleReminders(for: newItem, advanceDays: advanceDays)
        }
        return true
    }

    private var currentDraft: FoodFormDraft {
        FoodFormDraft(
            name: name,
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            hasExpirationDate: hasExpirationDate,
            photoData: photoData,
            notes: notes
        )
    }

    private func apply(_ draft: FoodFormDraft) {
        name = draft.name
        category = draft.category
        storageLocation = draft.storageLocation
        quantity = draft.quantity
        unit = draft.unit
        purchaseDate = draft.purchaseDate
        expirationDate = draft.expirationDate
        hasExpirationDate = draft.hasExpirationDate
        photoData = draft.photoData
        notes = draft.notes
        selectedImage = draft.photoData.flatMap { UIImage(data: $0) }
    }

    private enum SaveError: LocalizedError {
        case repositoryUnavailable

        var errorDescription: String? {
            NSLocalizedString("error.repositoryUnavailable", comment: "")
        }
    }
}
