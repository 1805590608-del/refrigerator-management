import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var cloudKitService: CloudKitService
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"
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
            .navigationTitle("nav.settings")
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
        Section(header: Text("settings.notifications")) {
            Toggle("settings.remind1", isOn: $remind1)
                .onChange(of: remind1) { _, _ in saveReminderDays() }
            Toggle("settings.remind3", isOn: $remind3)
                .onChange(of: remind3) { _, _ in saveReminderDays() }
            Toggle("settings.remind7", isOn: $remind7)
                .onChange(of: remind7) { _, _ in saveReminderDays() }
        }
    }

    private var syncSection: some View {
        Section(header: Text("settings.icloud")) {
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
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("settings.icloudUnavailableHint")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var syncStatusView: some View {
        switch cloudKitService.syncStatus {
        case .idle:
            return AnyView(Text("sync.idle").font(.caption).foregroundStyle(.secondary))
        case .syncing:
            return AnyView(HStack { ProgressView().scaleEffect(0.7); Text("sync.syncing").font(.caption) })
        case .synced:
            return AnyView(Text("sync.synced").font(.caption).foregroundStyle(.green))
        case .error(let msg):
            return AnyView(Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2))
        case .notLoggedIn:
            return AnyView(Text("sync.notLoggedIn").font(.caption).foregroundStyle(.orange))
        }
    }

    private var displaySection: some View {
        Section(header: Text("settings.display")) {
            Toggle("settings.gridView", isOn: $preferGridView)

            Picker("settings.colorScheme", selection: $colorSchemeRaw) {
                Text("colorScheme.system").tag("system")
                Text("colorScheme.light").tag("light")
                Text("colorScheme.dark").tag("dark")
            }
        }
    }

    private var dataSection: some View {
        Section(header: Text("settings.data")) {
            Button(role: .destructive) {
                showClearAlert = true
            } label: {
                Label("settings.clearHistory", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("settings.about")) {
            HStack {
                Text("settings.version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
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
        reminderDaysRaw = days.map { "\($0)" }.joined(separator: ",")
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
