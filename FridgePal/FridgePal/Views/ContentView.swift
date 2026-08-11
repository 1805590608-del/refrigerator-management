import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var shoppingItems: [ShoppingItem]

    private var pendingShoppingCount: Int {
        shoppingItems.filter { !$0.isCompleted }.count
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("tab.home", systemImage: "house.fill")
                }

            FoodListView()
                .tabItem {
                    Label("tab.list", systemImage: "list.bullet")
                }

            ShoppingListView()
                .tabItem {
                    Label("tab.shopping", systemImage: "cart.fill")
                }
                .badge(pendingShoppingCount)

            HistoryView()
                .tabItem {
                    Label("tab.history", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.accentColor)
        .toolbarBackground(.visible, for: .tabBar)
        .appToastOverlay()
    }
}
