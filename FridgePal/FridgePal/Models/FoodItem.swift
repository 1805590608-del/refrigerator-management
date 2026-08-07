import Foundation
import SwiftData

// MARK: - Enumerations

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case vegetable   = "vegetable"
    case fruit       = "fruit"
    case meat        = "meat"
    case dairy       = "dairy"
    case beverage    = "beverage"
    case condiment   = "condiment"
    case cooked      = "cooked"
    case other       = "other"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("category.\(rawValue)", comment: "")
    }

    var emoji: String {
        switch self {
        case .vegetable: return "🥦"
        case .fruit:     return "🍎"
        case .meat:      return "🥩"
        case .dairy:     return "🥛"
        case .beverage:  return "🥤"
        case .condiment: return "🧂"
        case .cooked:    return "🍱"
        case .other:     return "📦"
        }
    }
}

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge  = "fridge"
    case freezer = "freezer"
    case pantry  = "pantry"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("location.\(rawValue)", comment: "")
    }

    var emoji: String {
        switch self {
        case .fridge:  return "❄️"
        case .freezer: return "🧊"
        case .pantry:  return "🗄️"
        }
    }
}

enum FoodStatus: String, Codable, CaseIterable, Identifiable {
    case active   = "active"
    case eaten    = "eaten"
    case discarded = "discarded"
    case expired  = "expired"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("status.\(rawValue)", comment: "")
    }
}

// MARK: - FoodItem Model

@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String          // stored as rawValue
    var storageLocation: String   // stored as rawValue
    var quantity: Double
    var unit: String
    var purchaseDate: Date
    var expirationDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String
    var status: String            // stored as rawValue
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory = .other,
        storageLocation: StorageLocation = .fridge,
        quantity: Double = 1,
        unit: String = "item",
        purchaseDate: Date = Date(),
        expirationDate: Date? = nil,
        photoData: Data? = nil,
        notes: String = "",
        status: FoodStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category.rawValue
        self.storageLocation = storageLocation.rawValue
        self.quantity = quantity
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.photoData = photoData
        self.notes = notes
        self.status = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Computed helpers

    var categoryEnum: FoodCategory {
        get { FoodCategory(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }

    var storageLocationEnum: StorageLocation {
        get { StorageLocation(rawValue: storageLocation) ?? .fridge }
        set { storageLocation = newValue.rawValue }
    }

    var statusEnum: FoodStatus {
        get { FoodStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    /// Expiration state based on current date
    var expirationState: ExpirationState {
        guard let exp = expirationDate else { return .noDate }
        let now = Date()
        if exp < now { return .expired }
        let daysLeft = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? 0
        if daysLeft <= 3 { return .expiringSoon }
        return .fresh
    }

    var isActive: Bool { statusEnum == .active }
}

// MARK: - ExpirationState

enum ExpirationState {
    case fresh
    case expiringSoon
    case expired
    case noDate

    var color: String {
        switch self {
        case .fresh:        return "stateGreen"
        case .expiringSoon: return "stateOrange"
        case .expired:      return "stateRed"
        case .noDate:       return "stateGray"
        }
    }

    var localizedLabel: String {
        switch self {
        case .fresh:        return NSLocalizedString("expiration.fresh", comment: "")
        case .expiringSoon: return NSLocalizedString("expiration.soon", comment: "")
        case .expired:      return NSLocalizedString("expiration.expired", comment: "")
        case .noDate:       return NSLocalizedString("expiration.noDate", comment: "")
        }
    }
}
