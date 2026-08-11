import Foundation
import SwiftData
import Combine

enum SortOption: String, CaseIterable, Identifiable {
    case expirationDate = "expirationDate"
    case addedDate      = "addedDate"
    case name           = "name"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("sort.\(rawValue)", comment: "")
    }
}

enum FilterOption: String, CaseIterable, Identifiable {
    case all      = "all"
    case fresh    = "fresh"
    case soon     = "soon"
    case expired  = "expired"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("filter.\(rawValue)", comment: "")
    }
}

// MARK: - Bulk Actions

/// A batch operation that can be applied to several foods at once.
enum BulkAction: String, CaseIterable, Identifiable {
    case markEaten         = "markEaten"
    case markDiscarded     = "markDiscarded"
    case addToShoppingList = "addToShoppingList"
    case delete            = "delete"

    var id: String { rawValue }

    var localizedName: String {
        NSLocalizedString("bulk.\(rawValue)", comment: "")
    }

    var systemImage: String {
        switch self {
        case .markEaten:         return "checkmark.circle"
        case .markDiscarded:     return "trash.slash"
        case .addToShoppingList: return "cart.badge.plus"
        case .delete:            return "trash"
        }
    }

    /// True for actions that archive or permanently remove the selected foods.
    var isDestructive: Bool {
        switch self {
        case .markEaten, .markDiscarded, .delete: return true
        case .addToShoppingList:                  return false
        }
    }

    /// Batches that take foods out of the fridge are confirmed before they run.
    var requiresConfirmation: Bool {
        switch self {
        case .markEaten, .markDiscarded, .delete: return true
        case .addToShoppingList:                  return false
        }
    }

    func confirmationMessage(count: Int) -> String {
        let key: String
        switch self {
        case .markEaten:         key = "bulk.confirm.markEatenFormat"
        case .markDiscarded:     key = "bulk.confirm.markDiscardedFormat"
        case .addToShoppingList: key = "bulk.confirm.addToShoppingListFormat"
        case .delete:            key = "bulk.confirm.deleteFormat"
        }
        return String(format: NSLocalizedString(key, comment: ""), count)
    }

    func completionMessage(count: Int) -> String {
        let key: String
        switch self {
        case .markEaten:         key = "bulk.done.markEatenFormat"
        case .markDiscarded:     key = "bulk.done.markDiscardedFormat"
        case .addToShoppingList: key = "bulk.done.addToShoppingListFormat"
        case .delete:            key = "bulk.done.deleteFormat"
        }
        return String(format: NSLocalizedString(key, comment: ""), count)
    }
}

/// Tracks which foods are selected while the list is in multi-select mode.
struct BulkSelection: Equatable {
    private(set) var ids: Set<UUID> = []

    var isEmpty: Bool { ids.isEmpty }
    var count: Int { ids.count }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    mutating func toggle(_ id: UUID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    mutating func selectAll(_ items: [FoodItem]) {
        ids = Set(items.map(\.id))
    }

    mutating func clear() {
        ids.removeAll()
    }

    /// Drops selected identifiers that are no longer visible (filtered out, deleted, or archived).
    mutating func retain(in items: [FoodItem]) {
        let visible = Set(items.map(\.id))
        ids.formIntersection(visible)
    }

    /// Selected foods, in the display order of `items`.
    func resolve(from items: [FoodItem]) -> [FoodItem] {
        items.filter { ids.contains($0.id) }
    }

    /// True when every displayed food is already selected.
    func containsAll(of items: [FoodItem]) -> Bool {
        !items.isEmpty && items.allSatisfy { ids.contains($0.id) }
    }
}

@MainActor
final class FoodListViewModel: ObservableObject {
    @Published var items: [FoodItem] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .expirationDate
    @Published var filterOption: FilterOption = .all
    @Published var selectedCategory: FoodCategory? = nil
    @Published var selectedLocation: StorageLocation? = nil
    @Published var isGridView: Bool = false
    @Published var errorMessage: String?

    private let repository: FoodRepositoryProtocol
    private let notificationService = NotificationService.shared

    init(repository: FoodRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.fetchActive()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var displayedItems: [FoodItem] {
        var result = items

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        if let cat = selectedCategory {
            result = result.filter { $0.categoryEnum == cat }
        }

        // Filter by location
        if let loc = selectedLocation {
            result = result.filter { $0.storageLocationEnum == loc }
        }

        // Filter by expiration state
        switch filterOption {
        case .all:     break
        case .fresh:   result = result.filter { $0.expirationState == .fresh || $0.expirationState == .noDate }
        case .soon:    result = result.filter { $0.expirationState == .expiringSoon }
        case .expired: result = result.filter { $0.expirationState == .expired }
        }

        // Sort
        switch sortOption {
        case .name:
            result.sort { $0.name < $1.name }
        case .addedDate:
            result.sort { $0.createdAt > $1.createdAt }
        case .expirationDate:
            result.sort {
                guard let a = $0.expirationDate else { return false }
                guard let b = $1.expirationDate else { return true }
                return a < b
            }
        }

        return result
    }

    func delete(_ item: FoodItem, settings: ReminderSettings = .current()) {
        do {
            try repository.delete(item)
            load()
            notificationService.refreshSchedule(for: items, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markEaten(_ item: FoodItem, settings: ReminderSettings = .current()) {
        do {
            try repository.archiveItem(item, status: .eaten)
            load()
            notificationService.refreshSchedule(for: items, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markDiscarded(_ item: FoodItem, settings: ReminderSettings = .current()) {
        do {
            try repository.archiveItem(item, status: .discarded)
            load()
            notificationService.refreshSchedule(for: items, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
