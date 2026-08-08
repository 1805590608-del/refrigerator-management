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

@MainActor
final class FoodListViewModel: ObservableObject {
    @Published var items: [FoodItem] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .expirationDate
    @Published var filterOption: FilterOption = .all
    @Published var selectedCategory: FoodCategory? = nil
    @Published var selectedLocation: StorageLocation? = nil
    @Published var isGridView: Bool = false

    private let repository: FoodRepositoryProtocol
    private let notificationService = NotificationService.shared

    init(repository: FoodRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.fetchActive()
        } catch {
            items = []
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
        try? repository.delete(item)
        load()
        notificationService.refreshSchedule(for: items, settings: settings)
    }

    func markEaten(_ item: FoodItem, settings: ReminderSettings = .current()) {
        try? repository.archiveItem(item, status: .eaten)
        load()
        notificationService.refreshSchedule(for: items, settings: settings)
    }

    func markDiscarded(_ item: FoodItem, settings: ReminderSettings = .current()) {
        try? repository.archiveItem(item, status: .discarded)
        load()
        notificationService.refreshSchedule(for: items, settings: settings)
    }
}
