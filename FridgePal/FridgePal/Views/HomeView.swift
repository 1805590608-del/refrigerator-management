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

    private var recentItems: [FoodItem] { Array(activeItems.prefix(5)) }

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
                VStack(spacing: 20) {
                    // Sync status banner
                    SyncStatusBanner(status: cloudKitService.syncStatus)
                        .padding(.horizontal)

                    // Summary cards
                    summaryCards
                        .padding(.horizontal)

                    // Location breakdown
                    locationBreakdown
                        .padding(.horizontal)

                    // Recent items
                    recentSection
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.home")
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
        HStack(spacing: 12) {
            SummaryCard(
                title: NSLocalizedString("home.total", comment: ""),
                count: totalCount,
                color: .blue,
                icon: "archivebox.fill"
            )
            SummaryCard(
                title: NSLocalizedString("home.expiringSoon", comment: ""),
                count: expiringSoonCount,
                color: .orange,
                icon: "exclamationmark.circle.fill"
            )
            SummaryCard(
                title: NSLocalizedString("home.expired", comment: ""),
                count: expiredCount,
                color: .red,
                icon: "xmark.circle.fill"
            )
        }
    }

    private var locationBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.byLocation")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                LocationCard(location: .fridge,  count: fridgeItems.count)
                LocationCard(location: .freezer, count: freezerItems.count)
                LocationCard(location: .pantry,  count: pantryItems.count)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.recentItems")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if recentItems.isEmpty {
                EmptyStateView(message: "empty.noItems", icon: "refrigerator")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(recentItems) { item in
                    NavigationLink(destination: FoodDetailView(item: item)
                        .onDisappear { loadItems() }
                    ) {
                        FoodRowView(item: item)
                    }
                    .buttonStyle(.plain)
                }
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - LocationCard

struct LocationCard: View {
    let location: StorageLocation
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(location.emoji)
                .font(.title2)
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
            Text(location.localizedName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
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
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("sync.syncing")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.1), in: Capsule())
        case .error(let msg):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.red.opacity(0.1), in: Capsule())
        case .notLoggedIn:
            HStack {
                Image(systemName: "icloud.slash.fill")
                    .foregroundStyle(.orange)
                Text("sync.notLoggedIn")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.1), in: Capsule())
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    HomeView()
        .environmentObject(CloudKitService.shared)
        .modelContainer(PersistenceController.preview.container)
}
