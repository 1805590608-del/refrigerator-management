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
    var barcode: String
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
        barcode: String = "",
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
        self.barcode = barcode
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
            barcode: item.barcode,
            purchaseDate: item.purchaseDate,
            expirationDate: item.expirationDate ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: item.expirationDate != nil,
            photoData: item.photoData,
            notes: item.notes
        )
    }

    init(reusing item: FoodItem) {
        let shelfLifeDays = item.expirationDate.map {
            max(
                0,
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: item.purchaseDate),
                    to: Calendar.current.startOfDay(for: $0)
                ).day ?? item.categoryEnum.defaultShelfLifeDays
            )
        }
        let purchaseDate = Date()
        self.init(
            name: item.name,
            category: item.categoryEnum,
            storageLocation: item.storageLocationEnum,
            quantity: item.quantity,
            unit: item.unit,
            barcode: item.barcode,
            purchaseDate: purchaseDate,
            expirationDate: Calendar.current.date(
                byAdding: .day,
                value: shelfLifeDays ?? item.categoryEnum.defaultShelfLifeDays,
                to: purchaseDate
            ) ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: item.expirationDate != nil,
            photoData: item.photoData,
            notes: item.notes
        )
    }

    init(historyRecord: HistoryRecord) {
        let shelfLifeDays = historyRecord.expirationDate.map {
            max(
                0,
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: historyRecord.purchaseDate),
                    to: Calendar.current.startOfDay(for: $0)
                ).day ?? historyRecord.categoryEnum.defaultShelfLifeDays
            )
        }
        let purchaseDate = Date()
        self.init(
            name: historyRecord.foodName,
            category: historyRecord.categoryEnum,
            storageLocation: StorageLocation(rawValue: historyRecord.storageLocation) ?? .fridge,
            quantity: historyRecord.quantity,
            unit: historyRecord.unit,
            barcode: historyRecord.barcode,
            purchaseDate: purchaseDate,
            expirationDate: Calendar.current.date(
                byAdding: .day,
                value: shelfLifeDays ?? historyRecord.categoryEnum.defaultShelfLifeDays,
                to: purchaseDate
            ) ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: historyRecord.expirationDate != nil,
            photoData: historyRecord.photoData,
            notes: historyRecord.notes
        )
    }

    init(shoppingItem: ShoppingItem) {
        let purchaseDate = Date()
        self.init(
            name: shoppingItem.name,
            category: shoppingItem.categoryEnum,
            quantity: shoppingItem.preferredQuantity,
            unit: shoppingItem.unit,
            purchaseDate: purchaseDate,
            expirationDate: Calendar.current.date(
                byAdding: .day,
                value: shoppingItem.categoryEnum.defaultShelfLifeDays,
                to: purchaseDate
            ) ?? FoodFormDraft.defaultExpirationDate,
            hasExpirationDate: true
        )
    }

    func makeFoodItem() -> FoodItem {
        FoodItem(
            name: name,
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            barcode: barcode,
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
        item.barcode = barcode
        item.purchaseDate = purchaseDate
        item.expirationDate = hasExpirationDate ? expirationDate : nil
        item.photoData = photoData
        item.notes = notes
        item.updatedAt = Date()
    }

    static var defaultExpirationDate: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }
}

struct FoodTemplate: Identifiable {
    let id: String
    let draft: FoodFormDraft
    let useCount: Int
    let lastUsedAt: Date
}

enum FoodTemplateBuilder {
    static func templates(
        from records: [HistoryRecord],
        limit: Int = 5
    ) -> [FoodTemplate] {
        let grouped = Dictionary(grouping: records) {
            $0.foodName.trimmingCharacters(in: .whitespacesAndNewlines).folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
        }

        return grouped.compactMap { key, records -> FoodTemplate? in
            guard !key.isEmpty,
                  let latest = records.max(by: { $0.archivedAt < $1.archivedAt }) else {
                return nil
            }
            return FoodTemplate(
                id: key,
                draft: FoodFormDraft(historyRecord: latest),
                useCount: records.count,
                lastUsedAt: latest.archivedAt
            )
        }
        .sorted {
            if $0.useCount != $1.useCount {
                return $0.useCount > $1.useCount
            }
            return $0.lastUsedAt > $1.lastUsedAt
        }
        .prefix(max(0, limit))
        .map { $0 }
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
    @Published var barcode: String = ""
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

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
    func save(settings: ReminderSettings = .current()) throws -> Bool {
        guard let repository else {
            throw SaveError.repositoryUnavailable
        }
        return try save(to: repository, settings: settings)
    }

    @discardableResult
    func save(to repository: FoodRepositoryProtocol, settings: ReminderSettings = .current()) throws -> Bool {
        guard validate() else { return false }

        isSaving = true
        defer { isSaving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmedName
        let draft = currentDraft

        if let existingItem = item {
            draft.apply(to: existingItem)
            try repository.save(existingItem)
        } else {
            try repository.save(draft.makeFoodItem())
        }
        notificationService.refreshSchedule(using: repository, settings: settings)
        return true
    }

    private var currentDraft: FoodFormDraft {
        FoodFormDraft(
            name: name,
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            barcode: barcode,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            hasExpirationDate: hasExpirationDate,
            photoData: photoData,
            notes: notes
        )
    }

    func apply(_ draft: FoodFormDraft) {
        name = draft.name
        category = draft.category
        storageLocation = draft.storageLocation
        quantity = draft.quantity
        unit = draft.unit
        barcode = draft.barcode
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
