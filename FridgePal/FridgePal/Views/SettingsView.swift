import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var cloudKitService: CloudKitService
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"
    @AppStorage("reminderGroupedDigest") private var groupedDigest: Bool = true
    @AppStorage("reminderHour") private var reminderHour: Int = 9
    @AppStorage("preferGridView") private var preferGridView: Bool = false
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"
    @Environment(\.modelContext) private var modelContext

    @State private var showClearAlert = false
    @State private var remind1 = true
    @State private var remind3 = true
    @State private var remind7 = true

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                syncSection
                displaySection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { parseReminderDays() }
            .alert("alert.clearHistoryTitle", isPresented: $showClearAlert) {
                Button("button.clearAll", role: .destructive) { clearHistory() }
                Button("button.cancel", role: .cancel) {}
            } message: {
                Text("alert.clearHistoryMessage")
            }
        }
    }

    // MARK: Sections

    private var notificationSection: some View {
        Section {
            Toggle("settings.remind1", isOn: $remind1)
                .onChange(of: remind1) { _, _ in saveReminderDays() }
            Toggle("settings.remind3", isOn: $remind3)
                .onChange(of: remind3) { _, _ in saveReminderDays() }
            Toggle("settings.remind7", isOn: $remind7)
                .onChange(of: remind7) { _, _ in saveReminderDays() }

            Toggle("settings.groupedDigest", isOn: $groupedDigest)
                .onChange(of: groupedDigest) { _, newValue in
                    refreshReminders(groupedDigest: newValue)
                }

            Picker("settings.reminderTime", selection: $reminderHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(Self.hourLabel(hour)).tag(hour)
                }
            }
            .onChange(of: reminderHour) { _, newValue in
                refreshReminders(hour: newValue)
            }
        } header: {
            Text("settings.notifications")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        } footer: {
            Text(reminderExplanation)
                .font(.footnote)
        }
    }

    private var reminderExplanation: LocalizedStringKey {
        groupedDigest ? "settings.groupedDigest.footer" : "settings.perItemReminders.footer"
    }

    private var syncSection: some View {
        Section {
            HStack {
                Label("settings.syncStatus", systemImage: "icloud")
                Spacer()
                syncStatusView
            }
            Button {
                Task { await cloudKitService.checkAccountStatus() }
            } label: {
                Label("settings.checkSync", systemImage: "arrow.clockwise")
            }

            if !cloudKitService.isICloudAvailable {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.icloudUnavailable")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .systemOrange))
                    Text("settings.icloudUnavailableHint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("settings.icloud")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var syncStatusView: some View {
        switch cloudKitService.syncStatus {
        case .idle:
            return AnyView(Text("sync.idle").font(.footnote).foregroundStyle(.secondary))
        case .syncing:
            return AnyView(HStack { ProgressView().scaleEffect(0.7); Text("sync.syncing").font(.footnote) })
        case .synced:
            return AnyView(Text("sync.synced").font(.footnote).foregroundStyle(Color(uiColor: .systemGreen)))
        case .error(let msg):
            return AnyView(Text(msg).font(.footnote).foregroundStyle(Color(uiColor: .systemRed)).lineLimit(2))
        case .notLoggedIn:
            return AnyView(Text("sync.notLoggedIn").font(.footnote).foregroundStyle(Color(uiColor: .systemOrange)))
        }
    }

    private var displaySection: some View {
        Section {
            Toggle("settings.gridView", isOn: $preferGridView)

            Picker("settings.colorScheme", selection: $colorSchemeRaw) {
                Text("colorScheme.system").tag("system")
                Text("colorScheme.light").tag("light")
                Text("colorScheme.dark").tag("dark")
            }
        } header: {
            Text("settings.display")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showClearAlert = true
            } label: {
                Label("settings.clearHistory", systemImage: "trash")
                    .foregroundStyle(Color(uiColor: .systemRed))
            }
        } header: {
            Text("settings.data")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("settings.version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.about")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    // MARK: Helpers

    private func parseReminderDays() {
        let days = reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        remind1 = days.contains(1)
        remind3 = days.contains(3)
        remind7 = days.contains(7)
    }

    private func saveReminderDays() {
        var days: [Int] = []
        if remind1 { days.append(1) }
        if remind3 { days.append(3) }
        if remind7 { days.append(7) }
        let raw = days.map { "\($0)" }.joined(separator: ",")
        reminderDaysRaw = raw
        refreshReminders(rawAdvanceDays: raw)
    }

    /// Reminder settings apply to the whole inventory, so rebuild the schedule
    /// as soon as the user changes them.
    private func refreshReminders(
        rawAdvanceDays: String? = nil,
        groupedDigest: Bool? = nil,
        hour: Int? = nil
    ) {
        let settings = ReminderSettings(
            rawAdvanceDays: rawAdvanceDays ?? reminderDaysRaw,
            groupedDigest: groupedDigest ?? self.groupedDigest,
            hour: hour ?? reminderHour
        )
        NotificationService.shared.refreshSchedule(
            using: FoodRepository(context: modelContext),
            settings: settings
        )
    }

    private static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func clearHistory() {
        try? FoodRepository(context: modelContext).clearAllHistory()
    }
}

#Preview {
    SettingsView()
        .environmentObject(CloudKitService.shared)
        .modelContainer(PersistenceController.preview.container)
}
