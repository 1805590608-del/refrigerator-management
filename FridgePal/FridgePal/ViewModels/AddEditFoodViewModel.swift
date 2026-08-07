import Foundation
import SwiftUI
import SwiftData
import PhotosUI

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
    private let repository: FoodRepositoryProtocol
    private let notificationService = NotificationService.shared

    init(item: FoodItem? = nil, repository: FoodRepositoryProtocol) {
        self.item = item
        self.repository = repository
        self.isEditing = item != nil

        if let item {
            name = item.name
            category = item.categoryEnum
            storageLocation = item.storageLocationEnum
            quantity = item.quantity
            unit = item.unit
            purchaseDate = item.purchaseDate
            if let exp = item.expirationDate {
                expirationDate = exp
                hasExpirationDate = true
            } else {
                hasExpirationDate = false
            }
            notes = item.notes
            if let data = item.photoData {
                photoData = data
                selectedImage = UIImage(data: data)
            }
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

    func save(advanceDays: [Int]) throws {
        guard validate() else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let existingItem = item {
            existingItem.name = trimmedName
            existingItem.category = category.rawValue
            existingItem.storageLocation = storageLocation.rawValue
            existingItem.quantity = quantity
            existingItem.unit = unit
            existingItem.purchaseDate = purchaseDate
            existingItem.expirationDate = hasExpirationDate ? expirationDate : nil
            existingItem.photoData = photoData
            existingItem.notes = notes
            existingItem.updatedAt = Date()
            try repository.save(existingItem)
            notificationService.cancelReminders(for: existingItem)
            notificationService.scheduleReminders(for: existingItem, advanceDays: advanceDays)
        } else {
            let newItem = FoodItem(
                name: trimmedName,
                category: category,
                storageLocation: storageLocation,
                quantity: quantity,
                unit: unit,
                purchaseDate: purchaseDate,
                expirationDate: hasExpirationDate ? expirationDate : nil,
                photoData: photoData,
                notes: notes
            )
            try repository.save(newItem)
            notificationService.scheduleReminders(for: newItem, advanceDays: advanceDays)
        }
    }
}
