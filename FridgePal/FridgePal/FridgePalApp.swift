import SwiftUI
import SwiftData

@main
struct FridgePalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var feedbackCenter = AppFeedbackCenter()
    @AppStorage("preferGridView") var preferGridView: Bool = false
    @AppStorage(AppLanguageStorage.key) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

    init() {
        AppLanguageController.apply(UserDefaults.standard.string(forKey: AppLanguageStorage.key) ?? AppLanguage.system.rawValue)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(cloudKitService)
                .environmentObject(feedbackCenter)
                .environment(\.locale, currentLanguage.locale)
                .preferredColorScheme(preferredColorScheme)
                .id(appLanguageRaw)
                .onAppear {
                    AppLanguageController.apply(appLanguageRaw)
                }
                .onChange(of: appLanguageRaw) { _, newValue in
                    AppLanguageController.apply(newValue)
                    refreshReminders()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Reminders are day-based, so rebuild the schedule whenever the app
            // comes to the foreground to keep digests aligned with today.
            if newPhase == .active {
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

    @MainActor
    private func refreshReminders() {
        let repository = FoodRepository(context: PersistenceController.shared.container.mainContext)
        NotificationService.shared.refreshSchedule(using: repository)
    }
}
