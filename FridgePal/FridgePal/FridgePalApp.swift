import SwiftUI
import SwiftData
import UserNotifications

@main
struct FridgePalApp: App {
    @StateObject private var cloudKitService = CloudKitService.shared
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"
    @AppStorage("preferGridView") var preferGridView: Bool = false

    var reminderDays: [Int] {
        reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(cloudKitService)
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    private func requestNotificationPermission() {
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }
}
