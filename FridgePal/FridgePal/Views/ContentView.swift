import SwiftUI

struct ContentView: View {
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
    }
}
