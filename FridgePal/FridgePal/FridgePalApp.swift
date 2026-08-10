import SwiftUI
import SwiftData
import UserNotifications

@main
struct FridgePalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cloudKitService = CloudKitService.shared
    @AppStorage("preferGridView") var preferGridView: Bool = false
    @AppStorage(AppLanguageStorage.key) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"
    @State private var didStartNotificationSetup = false
    @State private var didFinishNotificationSetup = false

    init() {
        AppLanguageController.apply(UserDefaults.standard.string(forKey: AppLanguageStorage.key) ?? AppLanguage.system.rawValue)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(cloudKitService)
                .environment(\.locale, currentLanguage.locale)
                .preferredColorScheme(preferredColorScheme)
                .id(appLanguageRaw)
                .onAppear {
                    AppLanguageController.apply(appLanguageRaw)
                    guard !didStartNotificationSetup else { return }
                    didStartNotificationSetup = true
                    requestNotificationPermission()
                }
                .onChange(of: appLanguageRaw) { _, newValue in
                    AppLanguageController.apply(newValue)
                    refreshReminders()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Reminders are day-based, so rebuild the schedule whenever the app
            // comes to the foreground to keep digests aligned with today.
            if newPhase == .active && didFinishNotificationSetup {
                refreshReminders()
            }
        }
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light":
            .light
        case "dark":
            .dark
        default:
            nil
        }
    }

    private func requestNotificationPermission() {
        Task { @MainActor in
            let granted = await NotificationService.shared.requestAuthorization()
            if granted { refreshReminders() }
            didFinishNotificationSetup = true
        }
    }

    @MainActor
    private func refreshReminders() {
        let repository = FoodRepository(context: PersistenceController.shared.container.mainContext)
        NotificationService.shared.refreshSchedule(using: repository)
    }
}
