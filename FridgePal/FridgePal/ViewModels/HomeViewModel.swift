import Foundation
import SwiftData
import Combine

struct HomeAttentionItems {
    let expired: [FoodItem]
    let useToday: [FoodItem]
    let useSoon: [FoodItem]

    init(items: [FoodItem]) {
        var expired: [FoodItem] = []
        var useToday: [FoodItem] = []
        var useSoon: [FoodItem] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for item in items where item.isActive {
            switch item.expirationState {
            case .expired:
                expired.append(item)
            case .expiringSoon:
                if let expirationDate = item.expirationDate,
                   calendar.startOfDay(for: expirationDate) == today {
                    useToday.append(item)
                } else {
                    useSoon.append(item)
                }
            case .fresh, .noDate:
                break
            }
        }

        self.expired = expired.sorted {
            ($0.expirationDate ?? .distantPast) > ($1.expirationDate ?? .distantPast)
        }
        self.useToday = useToday.sorted { $0.name < $1.name }
        self.useSoon = useSoon.sorted {
            ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture)
        }
    }

    var isEmpty: Bool {
        expired.isEmpty && useToday.isEmpty && useSoon.isEmpty
    }

    var expiringSoonCount: Int {
        useToday.count + useSoon.count
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var activeItems: [FoodItem] = []
    @Published var searchText: String = ""
    @Published var errorMessage: String?

    private let repository: FoodRepositoryProtocol

    init(repository: FoodRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        do {
            activeItems = try repository.fetchActive()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var totalCount: Int { activeItems.count }

    var attentionItems: HomeAttentionItems {
        HomeAttentionItems(items: activeItems)
    }

    var expiringSoonCount: Int { attentionItems.expiringSoonCount }

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
