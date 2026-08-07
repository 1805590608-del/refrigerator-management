import Foundation
import SwiftData
import Combine

struct HomeAttentionItems {
    let expired: [FoodItem]
    let useSoon: [FoodItem]

    init(items: [FoodItem]) {
        var expired: [FoodItem] = []
        var useSoon: [FoodItem] = []

        for item in items where item.isActive {
            switch item.expirationState {
            case .expired:
                expired.append(item)
            case .expiringSoon:
                useSoon.append(item)
            case .fresh, .noDate:
                break
            }
        }

        self.expired = expired.sorted {
            ($0.expirationDate ?? .distantPast) > ($1.expirationDate ?? .distantPast)
        }
        self.useSoon = useSoon.sorted {
            ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture)
        }
    }

    var isEmpty: Bool {
        expired.isEmpty && useSoon.isEmpty
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var activeItems: [FoodItem] = []
    @Published var searchText: String = ""

    private let repository: FoodRepositoryProtocol

    init(repository: FoodRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        do {
            activeItems = try repository.fetchActive()
        } catch {
            activeItems = []
        }
    }

    var totalCount: Int { activeItems.count }

    private var attentionItems: HomeAttentionItems {
        HomeAttentionItems(items: activeItems)
    }

    var expiringSoonCount: Int { attentionItems.useSoon.count }

    var expiredCount: Int { attentionItems.expired.count }

    var recentItems: [FoodItem] {
        Array(activeItems.prefix(5))
    }

    var fridgeItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .fridge } }
    var freezerItems: [FoodItem] { activeItems.filter { $0.storageLocationEnum == .freezer } }
    var pantryItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .pantry } }

    var filteredItems: [FoodItem] {
        guard !searchText.isEmpty else { return activeItems }
        return activeItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.categoryEnum.localizedName.localizedCaseInsensitiveContains(searchText)
        }
    }
}
