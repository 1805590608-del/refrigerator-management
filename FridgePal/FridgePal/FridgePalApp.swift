import SwiftUI
import SwiftData
import UserNotifications

@main
struct FridgePalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cloudKitService = CloudKitService.shared
    @AppStorage("preferGridView") var preferGridView: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(cloudKitService)
                .onAppear {
                    requestNotificationPermission()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Reminders are day-based, so rebuild the schedule whenever the app
            // comes to the foreground to keep digests aligned with today.
            if newPhase == .active { refreshReminders() }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted { refreshReminders() }
        }
    }

    @MainActor
    private func refreshReminders() {
        let repository = FoodRepository(context: PersistenceController.shared.container.mainContext)
        NotificationService.shared.refreshSchedule(using: repository)
    }
}
