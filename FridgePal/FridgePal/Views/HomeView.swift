import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var cloudKitService: CloudKitService
    @State private var activeItems: [FoodItem] = []
    @State private var searchText = ""
    @State private var showAddFood = false

    // MARK: - Computed stats

    private var totalCount: Int { activeItems.count }

    private var expiringSoonCount: Int {
        activeItems.filter { $0.expirationState == .expiringSoon }.count
    }

    private var expiredCount: Int {
        activeItems.filter { $0.expirationState == .expired }.count
    }

    private var recentItems: [FoodItem] { Array(filteredItems.prefix(5)) }

    private var fridgeItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .fridge } }
    private var freezerItems: [FoodItem] { activeItems.filter { $0.storageLocationEnum == .freezer } }
    private var pantryItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .pantry } }

    private var filteredItems: [FoodItem] {
        guard !searchText.isEmpty else { return activeItems }
        return activeItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.categoryEnum.localizedName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var repository: FoodRepository { FoodRepository(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    SyncStatusBanner(status: cloudKitService.syncStatus)
                    summaryCards
                    locationBreakdown
                    recentSection
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.large)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.home")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "search.prompt")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFood = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("button.addFood")
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddEditFoodView(item: nil)
                    .onDisappear { loadItems() }
            }
            .onAppear { loadItems() }
        }
    }

    // MARK: - Sub-views

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: AppSpacing.medium)], spacing: AppSpacing.medium) {
            SummaryCard(
                title: NSLocalizedString("home.total", comment: ""),
                count: totalCount,
                color: Color(uiColor: .systemBlue),
                icon: "archivebox.fill"
            )
            SummaryCard(
                title: NSLocalizedString("home.expiringSoon", comment: ""),
                count: expiringSoonCount,
                color: Color(uiColor: .systemOrange),
                icon: "exclamationmark.circle.fill"
            )
            SummaryCard(
                title: NSLocalizedString("home.expired", comment: ""),
                count: expiredCount,
                color: Color(uiColor: .systemRed),
                icon: "xmark.circle.fill"
            )
        }
    }

    private var locationBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(title: "home.byLocation")
            HStack(spacing: AppSpacing.medium) {
                LocationCard(location: .fridge,  count: fridgeItems.count)
                LocationCard(location: .freezer, count: freezerItems.count)
                LocationCard(location: .pantry,  count: pantryItems.count)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(title: "home.recentItems")

            if recentItems.isEmpty {
                EmptyStateView(message: "empty.noItems", icon: "refrigerator")
                    .frame(maxWidth: .infinity)
                    .appCardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(destination: FoodDetailView(item: item)
                            .onDisappear { loadItems() }
                        ) {
                            FoodRowView(item: item)
                                .padding(.horizontal, AppSpacing.large)
                                .padding(.vertical, AppSpacing.medium)
                        }
                        .buttonStyle(.plain)

                        if index < recentItems.count - 1 {
                            Divider()
                                .padding(.leading, AppSpacing.large + 56 + AppSpacing.medium)
                        }
                    }
                }
                .appCardStyle(padding: 0)
            }
        }
    }

    private func loadItems() {
        activeItems = (try? repository.fetchActive()) ?? []
    }
}

// MARK: - SummaryCard

struct SummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            Text("\(count)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 132, alignment: .topLeading)
        .appCardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - LocationCard

struct LocationCard: View {
    let location: StorageLocation
    let count: Int

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text(location.emoji)
                .font(.title2)
            Text("\(count)")
                .font(.headline.weight(.semibold))
            Text(location.localizedName)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.medium)
        .appCardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - SyncStatusBanner

struct SyncStatusBanner: View {
    let status: SyncStatus

    var body: some View {
        switch status {
        case .idle, .synced:
            EmptyView()
        case .syncing:
            StatusBadge(
                title: NSLocalizedString("sync.syncing", comment: ""),
                systemImage: "arrow.triangle.2.circlepath",
                tint: .accentColor
            )
        case .error(let msg):
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                StatusBadge(
                    title: NSLocalizedString("alert.errorTitle", comment: ""),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Color(uiColor: .systemRed)
                )
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle()
        case .notLoggedIn:
            StatusBadge(
                title: NSLocalizedString("sync.notLoggedIn", comment: ""),
                systemImage: "icloud.slash.fill",
                tint: Color(uiColor: .systemOrange)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, height: 60)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Circle())
            Text(LocalizedStringKey(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xxLarge)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
        .environmentObject(CloudKitService.shared)
        .modelContainer(PersistenceController.preview.container)
}
