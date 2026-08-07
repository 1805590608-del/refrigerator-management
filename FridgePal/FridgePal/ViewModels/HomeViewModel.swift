import Foundation
import SwiftData
import Combine

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

    var expiringSoonCount: Int {
        activeItems.filter { $0.expirationState == .expiringSoon }.count
    }

    var expiredCount: Int {
        activeItems.filter { $0.expirationState == .expired }.count
    }

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
