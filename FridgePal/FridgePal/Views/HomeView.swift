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

    private var attentionItems: HomeAttentionItems {
        HomeAttentionItems(items: activeItems)
    }

    private var expiringSoonCount: Int { attentionItems.useSoon.count }

    private var expiredCount: Int { attentionItems.expired.count }

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
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    SyncStatusBanner(status: cloudKitService.syncStatus)
                    attentionSection
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

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(
                title: "home.needsAttention",
                subtitle: "home.needsAttentionSubtitle"
            )

            if attentionItems.isEmpty {
                HomeAttentionAllClearView()
            } else {
                if !attentionItems.expired.isEmpty {
                    HomeActionGroup(
                        kind: .expired,
                        items: attentionItems.expired,
                        onItemChange: loadItems
                    )
                }

                if !attentionItems.useSoon.isEmpty {
                    HomeActionGroup(
                        kind: .useSoon,
                        items: attentionItems.useSoon,
                        onItemChange: loadItems
                    )
                }
            }
        }
    }

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
                                .padding(.leading, AppSpacing.large + AppSizing.defaultThumbnailSize + AppSpacing.medium)
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

// MARK: - Home actions

private enum HomeActionKind {
    case expired
    case useSoon

    var title: LocalizedStringKey {
        switch self {
        case .expired:
            "home.expiredNow"
        case .useSoon:
            "home.useSoon"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .expired:
            "home.expiredNowSubtitle"
        case .useSoon:
            "home.useSoonSubtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .expired:
            "exclamationmark.triangle.fill"
        case .useSoon:
            "clock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .expired:
            Color(uiColor: .systemRed)
        case .useSoon:
            Color(uiColor: .systemOrange)
        }
    }

    func items(in attentionItems: HomeAttentionItems) -> [FoodItem] {
        switch self {
        case .expired:
            attentionItems.expired
        case .useSoon:
            attentionItems.useSoon
        }
    }
}

private struct HomeActionGroup: View {
    private let maximumVisibleItems = 3

    let kind: HomeActionKind
    let items: [FoodItem]
    let onItemChange: () -> Void

    private var visibleItems: [FoodItem] {
        Array(items.prefix(maximumVisibleItems))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.headline)
                        .foregroundStyle(kind.tint)
                    Text(kind.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Spacer(minLength: AppSpacing.medium)

                Text(items.count, format: .number)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(kind.tint)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(kind.tint.opacity(AppOpacity.badgeFill), in: Capsule())
            }
            .padding(AppSpacing.large)

            Divider()

            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    FoodDetailView(item: item)
                        .onDisappear(perform: onItemChange)
                } label: {
                    FoodRowView(item: item)
                        .padding(.horizontal, AppSpacing.large)
                        .padding(.vertical, AppSpacing.small)
                }
                .buttonStyle(.plain)
                .accessibilityHint("accessibility.openFoodDetails")

                if index < visibleItems.count - 1 {
                    Divider()
                        .padding(.leading, AppSpacing.large + AppSizing.defaultThumbnailSize + AppSpacing.medium)
                }
            }

            if items.count > maximumVisibleItems {
                Divider()
                NavigationLink {
                    HomeActionListView(kind: kind)
                } label: {
                    HStack {
                        Text("home.viewAll")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(kind.tint)
                    .padding(AppSpacing.large)
                }
                .buttonStyle(.plain)
            }
        }
        .appCardStyle(padding: 0)
    }
}

private struct HomeAttentionAllClearView: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(uiColor: .systemGreen))

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("home.allClear")
                    .font(.headline)
                Text("home.allClearSubtitle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct HomeActionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeItems: [FoodItem] = []

    let kind: HomeActionKind

    private var repository: FoodRepository {
        FoodRepository(context: modelContext)
    }

    private var items: [FoodItem] {
        kind.items(in: HomeAttentionItems(items: activeItems))
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(message: "home.noActionItems", icon: "checkmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    NavigationLink {
                        FoodDetailView(item: item)
                            .onDisappear(perform: loadItems)
                    } label: {
                        FoodRowView(item: item)
                            .padding(.vertical, AppSpacing.xSmall)
                    }
                    .accessibilityHint("accessibility.openFoodDetails")
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadItems)
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
