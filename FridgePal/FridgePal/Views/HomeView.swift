import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var cloudKitService: CloudKitService
    @State private var dismissedSyncNoticeIdentifier: String?
    @State private var activeItems: [FoodItem] = []
    @State private var searchText = ""
    @State private var showAddFood = false
    @State private var dataError: String?

    // MARK: - Computed stats

    private var totalCount: Int { activeItems.count }

    private var recentItems: [FoodItem] { Array(activeItems.prefix(5)) }

    private var fridgeItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .fridge } }
    private var freezerItems: [FoodItem] { activeItems.filter { $0.storageLocationEnum == .freezer } }
    private var pantryItems: [FoodItem]  { activeItems.filter { $0.storageLocationEnum == .pantry } }

    private var filteredItems: [FoodItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activeItems }
        return activeItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.categoryEnum.localizedName.localizedCaseInsensitiveContains(query) ||
            $0.storageLocationEnum.localizedName.localizedCaseInsensitiveContains(query)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var repository: FoodRepository { FoodRepository(context: modelContext) }

    private var metricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.medium),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 3
        )
    }

    var body: some View {
        let attentionItems = HomeAttentionItems(items: activeItems)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    if let syncNoticeIdentifier,
                       dismissedSyncNoticeIdentifier != syncNoticeIdentifier {
                        SyncStatusBanner(
                            status: cloudKitService.syncStatus,
                            onDismiss: {
                                dismissedSyncNoticeIdentifier = syncNoticeIdentifier
                            }
                        )
                    }
                    if isSearching {
                        searchResultsSection
                    } else if activeItems.isEmpty {
                        HomeOnboardingView(addAction: { showAddFood = true })
                    } else {
                        attentionSection(attentionItems)
                        summaryCards(attentionItems)
                        locationBreakdown
                        recentSection
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)
                .padding(.bottom, AppSpacing.xxLarge)
            }
            .refreshable { loadItems() }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.home")
            .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
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
            .alert("alert.errorTitle", isPresented: Binding(
                get: { dataError != nil },
                set: { if !$0 { dataError = nil } }
            )) {
                Button("button.ok") { dataError = nil }
            } message: {
                Text(dataError ?? "")
            }
            .onAppear { loadItems() }
            .onChange(of: syncNoticeIdentifier) { oldValue, newValue in
                if oldValue != newValue {
                    dismissedSyncNoticeIdentifier = nil
                }
            }
        }
    }

    // MARK: - Sub-views

    private func attentionSection(_ attentionItems: HomeAttentionItems) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(
                title: "home.needsAttention",
                subtitle: "home.needsAttentionSubtitle"
            )

            if attentionItems.isEmpty {
                HomeAttentionAllClearView()
            } else {
                if !attentionItems.useToday.isEmpty {
                    HomeActionGroup(
                        kind: .today,
                        items: attentionItems.useToday,
                        onItemChange: loadItems
                    )
                }

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

    private func summaryCards(_ attentionItems: HomeAttentionItems) -> some View {
        LazyVGrid(
            columns: metricColumns,
            spacing: AppSpacing.medium
        ) {
            NavigationLink {
                HomeMetricListView(selection: .all, onItemChange: loadItems)
            } label: {
                SummaryCard(
                    title: NSLocalizedString("home.total", comment: ""),
                    count: totalCount,
                    color: Color(uiColor: .systemBlue),
                    icon: "refrigerator.fill"
                )
            }
            .buttonStyle(HomeMetricButtonStyle())
            .accessibilityLabel(metricAccessibilityLabel(
                title: NSLocalizedString("home.total", comment: ""),
                count: totalCount
            ))
            .accessibilityHint("accessibility.openFilteredList")

            NavigationLink {
                HomeMetricListView(selection: .expiringSoon, onItemChange: loadItems)
            } label: {
                SummaryCard(
                    title: NSLocalizedString("home.expiringSoon", comment: ""),
                    count: attentionItems.expiringSoonCount,
                    color: Color(uiColor: .systemOrange),
                    icon: "clock.fill"
                )
            }
            .buttonStyle(HomeMetricButtonStyle())
            .accessibilityLabel(metricAccessibilityLabel(
                title: NSLocalizedString("home.expiringSoon", comment: ""),
                count: attentionItems.expiringSoonCount
            ))
            .accessibilityHint("accessibility.openFilteredList")

            NavigationLink {
                HomeMetricListView(selection: .expired, onItemChange: loadItems)
            } label: {
                SummaryCard(
                    title: NSLocalizedString("home.expired", comment: ""),
                    count: attentionItems.expired.count,
                    color: Color(uiColor: .systemRed),
                    icon: "exclamationmark.triangle.fill"
                )
            }
            .buttonStyle(HomeMetricButtonStyle())
            .accessibilityLabel(metricAccessibilityLabel(
                title: NSLocalizedString("home.expired", comment: ""),
                count: attentionItems.expired.count
            ))
            .accessibilityHint("accessibility.openFilteredList")
        }
    }

    private var locationBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "home.byLocation")
            LazyVGrid(
                columns: metricColumns,
                spacing: AppSpacing.medium
            ) {
                locationLink(for: .fridge, count: fridgeItems.count)
                locationLink(for: .freezer, count: freezerItems.count)
                locationLink(for: .pantry, count: pantryItems.count)
            }
        }
    }

    private func locationLink(for location: StorageLocation, count: Int) -> some View {
        NavigationLink {
            HomeMetricListView(selection: .location(location), onItemChange: loadItems)
        } label: {
            LocationCard(location: location, count: count)
        }
        .buttonStyle(HomeMetricButtonStyle())
        .accessibilityLabel(metricAccessibilityLabel(title: location.localizedName, count: count))
        .accessibilityHint("accessibility.openFilteredList")
    }

    private func metricAccessibilityLabel(title: String, count: Int) -> Text {
        Text(
            String(
                format: NSLocalizedString("accessibility.metricCountFormat", comment: ""),
                title.replacingOccurrences(of: "\n", with: " "),
                count
            )
        )
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

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "home.searchResults")

            if filteredItems.isEmpty {
                EmptyStateView(message: "empty.noSearchResults", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
                    .appCardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            FoodDetailView(item: item)
                                .onDisappear(perform: loadItems)
                        } label: {
                            FoodRowView(item: item)
                                .padding(.horizontal, AppSpacing.large)
                                .padding(.vertical, AppSpacing.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("accessibility.openFoodDetails"))

                        if index < filteredItems.count - 1 {
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
        do {
            activeItems = try repository.fetchActive()
        } catch {
            dataError = error.localizedDescription
        }
    }

    private var syncNoticeIdentifier: String? {
        switch cloudKitService.syncStatus {
        case .idle, .synced:
            nil
        case .syncing:
            "syncing"
        case .notLoggedIn:
            "notLoggedIn"
        case .error(let message):
            "error:\(message)"
        }
    }
}

// MARK: - Home actions

private enum HomeActionKind {
    case today
    case expired
    case useSoon

    var title: LocalizedStringKey {
        switch self {
        case .today:
            "home.useToday"
        case .expired:
            "home.expiredNow"
        case .useSoon:
            "home.useSoon"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .today:
            "home.useTodaySubtitle"
        case .expired:
            "home.expiredNowSubtitle"
        case .useSoon:
            "home.useSoonSubtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            "fork.knife"
        case .expired:
            "exclamationmark.triangle.fill"
        case .useSoon:
            "clock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .today:
            Color(uiColor: .systemIndigo)
        case .expired:
            Color(uiColor: .systemRed)
        case .useSoon:
            Color(uiColor: .systemOrange)
        }
    }

    func items(in attentionItems: HomeAttentionItems) -> [FoodItem] {
        switch self {
        case .today:
            attentionItems.useToday
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
                .accessibilityHint(Text("accessibility.openFoodDetails"))

                if index < visibleItems.count - 1 {
                    Divider()
                        .padding(.leading, AppSpacing.large + AppSizing.defaultThumbnailSize + AppSpacing.medium)
                }
            }

            if items.count > maximumVisibleItems {
                Divider()
                NavigationLink {
                    HomeActionListView(kind: kind, onItemChange: onItemChange)
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
    @State private var dataError: String?

    let kind: HomeActionKind
    let onItemChange: () -> Void

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
                            .onDisappear(perform: reloadItems)
                    } label: {
                        FoodRowView(item: item)
                            .padding(.vertical, AppSpacing.xSmall)
                    }
                    .accessibilityHint(Text("accessibility.openFoodDetails"))
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadItems)
        .alert("alert.errorTitle", isPresented: Binding(
            get: { dataError != nil },
            set: { if !$0 { dataError = nil } }
        )) {
            Button("button.ok") { dataError = nil }
        } message: {
            Text(dataError ?? "")
        }
    }

    private func loadItems() {
        do {
            activeItems = try FoodRepository(context: modelContext).fetchActive()
        } catch {
            dataError = error.localizedDescription
        }
    }

    private func reloadItems() {
        loadItems()
        onItemChange()
    }
}

private enum HomeMetricSelection {
    case all
    case expiringSoon
    case expired
    case location(StorageLocation)

    var title: String {
        switch self {
        case .all:
            NSLocalizedString("home.total", comment: "")
        case .expiringSoon:
            NSLocalizedString("home.expiringSoon", comment: "")
        case .expired:
            NSLocalizedString("home.expired", comment: "")
        case .location(let location):
            location.localizedName
        }
    }

    func filter(_ items: [FoodItem]) -> [FoodItem] {
        switch self {
        case .all:
            items
        case .expiringSoon:
            items.filter { $0.expirationState == .expiringSoon }
        case .expired:
            items.filter { $0.expirationState == .expired }
        case .location(let location):
            items.filter { $0.storageLocationEnum == location }
        }
    }
}

private struct HomeMetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeItems: [FoodItem] = []
    @State private var dataError: String?

    let selection: HomeMetricSelection
    let onItemChange: () -> Void

    private var items: [FoodItem] {
        selection.filter(activeItems)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(message: "empty.noItems", icon: "refrigerator")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    NavigationLink {
                        FoodDetailView(item: item)
                            .onDisappear(perform: reloadItems)
                    } label: {
                        FoodRowView(item: item)
                            .padding(.vertical, AppSpacing.xSmall)
                    }
                    .accessibilityHint(Text("accessibility.openFoodDetails"))
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(selection.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadItems)
        .alert("alert.errorTitle", isPresented: Binding(
            get: { dataError != nil },
            set: { if !$0 { dataError = nil } }
        )) {
            Button("button.ok") { dataError = nil }
        } message: {
            Text(dataError ?? "")
        }
    }

    private func loadItems() {
        do {
            activeItems = try FoodRepository(context: modelContext).fetchActive()
        } catch {
            dataError = error.localizedDescription
        }
    }

    private func reloadItems() {
        loadItems()
        onItemChange()
    }
}

// MARK: - SummaryCard

struct SummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: AppSpacing.medium) {
                    metricIcon
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("\(count)")
                            .font(.title.bold())
                            .monospacedDigit()
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: AppSpacing.small)
                    chevron
                }
            } else {
                VStack(spacing: AppSpacing.small) {
                    metricIcon
                    Text("\(count)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 126)
                .overlay(alignment: .topTrailing) {
                    chevron
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.medium)
        .background(HomeMetricCardBackground(tint: color))
        .accessibilityElement(children: .combine)
    }

    private var metricIcon: some View {
        Image(systemName: icon)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            .shadow(color: color.opacity(0.22), radius: 5, y: 3)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - LocationCard

struct LocationCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: StorageLocation
    let count: Int

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: AppSpacing.medium) {
                    locationIcon
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text("\(count)")
                            .font(.title.bold())
                            .monospacedDigit()
                        Text(location.localizedName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: AppSpacing.small)
                    chevron
                }
            } else {
                VStack(spacing: AppSpacing.small) {
                    locationIcon
                    Text("\(count)")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(location.localizedName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(minHeight: 116)
                .overlay(alignment: .topTrailing) {
                    chevron
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.medium)
        .background(HomeMetricCardBackground(tint: tint))
        .accessibilityElement(children: .combine)
    }

    private var locationIcon: some View {
        Image(systemName: icon)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            .shadow(color: tint.opacity(0.2), radius: 4, y: 2)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var icon: String {
        switch location {
        case .fridge:
            "refrigerator.fill"
        case .freezer:
            "snowflake"
        case .pantry:
            "shippingbox.fill"
        }
    }

    private var tint: Color {
        switch location {
        case .fridge:
            Color(uiColor: .systemBlue)
        case .freezer:
            Color(uiColor: .systemCyan)
        case .pantry:
            Color(uiColor: .systemBrown)
        }
    }
}

private struct HomeMetricCardBackground: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.16),
                        Color(uiColor: .secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
            }
    }
}

// MARK: - SyncStatusBanner

struct SyncStatusBanner: View {
    let status: SyncStatus
    var onDismiss: (() -> Void)? = nil

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
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: "icloud.slash.fill")
                    .foregroundStyle(Color(uiColor: .systemOrange))
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: AppSpacing.xSmall)
                dismissButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(padding: AppSpacing.medium)
        case .notLoggedIn:
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: "icloud.slash.fill")
                    .foregroundStyle(Color(uiColor: .systemOrange))
                Text("sync.notLoggedIn")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: AppSpacing.xSmall)
                dismissButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(padding: AppSpacing.medium)
        }
    }

    @ViewBuilder
    private var dismissButton: some View {
        if let onDismiss {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("button.dismiss")
        }
    }
}

private struct HomeOnboardingView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xLarge) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.xLarge, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 112, height: 112)
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppSpacing.small) {
                Text("onboarding.emptyTitle")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("onboarding.emptySubtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: addAction) {
                Label("onboarding.addFirstItem", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(AppSpacing.xLarge)
        .frame(maxWidth: .infinity)
        .appCardStyle()
    }
}

private struct HomeMetricButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
