import SwiftUI
import SwiftData

struct FoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter
    @AppStorage("preferGridView") private var preferGridView: Bool = false
    @AppStorage("foodSortOption") private var sortOptionRawValue = SortOption.expirationDate.rawValue
    @State private var items: [FoodItem] = []
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedLocation: StorageLocation? = nil
    @State private var showAddFood = false
    @State private var itemToDelete: FoodItem? = nil
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selection = BulkSelection()
    @State private var pendingBulkAction: BulkAction? = nil
    @State private var operationError: String?

    private var repository: FoodRepository { FoodRepository(context: modelContext) }
    private var shoppingRepository: ShoppingRepository { ShoppingRepository(context: modelContext) }
    private var sortOption: SortOption {
        SortOption(rawValue: sortOptionRawValue) ?? .expirationDate
    }

    private var displayedItems: [FoodItem] {
        var result = items
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let cat = selectedCategory {
            result = result.filter { $0.categoryEnum == cat }
        }
        if let loc = selectedLocation {
            result = result.filter { $0.storageLocationEnum == loc }
        }
        switch filterOption {
        case .all:     break
        case .fresh:   result = result.filter { $0.expirationState == .fresh || $0.expirationState == .noDate }
        case .soon:    result = result.filter { $0.expirationState == .expiringSoon }
        case .expired: result = result.filter { $0.expirationState == .expired }
        }
        switch sortOption {
        case .name:           result.sort { $0.name < $1.name }
        case .addedDate:      result.sort { $0.createdAt > $1.createdAt }
        case .expirationDate: result.sort {
            guard let a = $0.expirationDate else { return false }
            guard let b = $1.expirationDate else { return true }
            return a < b
        }
        }
        return result
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        filterOption != .all ||
        selectedCategory != nil ||
        selectedLocation != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !items.isEmpty && !isSelecting {
                    filterSummaryBar
                }

                Group {
                    if items.isEmpty {
                        EmptyStateView(message: "empty.noItems", icon: "refrigerator")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if displayedItems.isEmpty {
                        filteredEmptyState
                    } else if preferGridView && !isSelecting {
                        gridView
                    } else {
                        listView
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.list")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "search.prompt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("button.cancel") { exitSelectionMode() }
                    } else {
                        filterMenu
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        Button("button.done") { exitSelectionMode() }
                            .fontWeight(.semibold)
                    } else {
                        HStack {
                            Button {
                                preferGridView.toggle()
                            } label: {
                                Image(systemName: preferGridView ? "list.bullet" : "square.grid.2x2")
                            }
                            .accessibilityLabel(preferGridView ? "button.listView" : "button.gridView")

                            Button {
                                isSelecting = true
                                selection.clear()
                            } label: {
                                Image(systemName: "checklist")
                            }
                            .accessibilityLabel("button.select")
                            .disabled(displayedItems.isEmpty)

                            Button {
                                showAddFood = true
                            } label: {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                            .accessibilityLabel("button.addFood")
                        }
                    }
                }
                if isSelecting {
                    ToolbarItemGroup(placement: .bottomBar) {
                        selectAllButton
                        Spacer()
                        Text(selectionCountLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(selectionCountLabel)
                        Spacer()
                        bulkActionMenu
                    }
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddEditFoodView(item: nil)
                    .onDisappear { loadItems() }
            }
            .alert("alert.deleteTitle", isPresented: $showDeleteAlert) {
                Button("button.delete", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
                Button("button.cancel", role: .cancel) {}
            } message: {
                Text("alert.deleteMessage")
            }
            .confirmationDialog(
                "bulk.confirmTitle",
                isPresented: Binding(
                    get: { pendingBulkAction != nil },
                    set: { if !$0 { pendingBulkAction = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingBulkAction
            ) { action in
                Button(action.localizedName, role: .destructive) {
                    perform(action)
                    pendingBulkAction = nil
                }
                Button("button.cancel", role: .cancel) { pendingBulkAction = nil }
            } message: { action in
                Text(action.confirmationMessage(count: selection.count))
            }
            .alert("alert.errorTitle", isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )) {
                Button("button.ok") { operationError = nil }
            } message: {
                Text(operationError ?? "")
            }
            .onChange(of: searchText) { _, _ in
                guard isSelecting else { return }
                selection.retain(in: displayedItems)
                if selection.isEmpty { exitSelectionMode() }
            }
            .onAppear { loadItems() }
        }
    }

    // MARK: List View

    private var listView: some View {
        List {
            Section {
                ForEach(displayedItems) { item in
                    if isSelecting {
                        selectableRow(for: item)
                    } else {
                        NavigationLink(destination: FoodDetailView(item: item).onDisappear { loadItems() }) {
                            FoodRowView(item: item)
                                .padding(.vertical, AppSpacing.xSmall)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("button.delete", systemImage: "trash")
                            }

                            Button {
                                markEaten(item)
                            } label: {
                                Label("status.eaten", systemImage: "checkmark.circle")
                            }
                            .tint(Color(uiColor: .systemGreen))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { loadItems() }
    }

    private func selectableRow(for item: FoodItem) -> some View {
        let isSelected = selection.contains(item.id)
        return Button {
            selection.toggle(item.id)
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)

                FoodRowView(item: item)
                    .padding(.vertical, AppSpacing.xSmall)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint("accessibility.toggleSelection")
    }

    // MARK: Bulk Action Controls

    private var selectAllButton: some View {
        let allSelected = selection.containsAll(of: displayedItems)
        return Button(allSelected ? "bulk.deselectAll" : "bulk.selectAll") {
            if allSelected {
                selection.clear()
            } else {
                selection.selectAll(displayedItems)
            }
        }
        .disabled(displayedItems.isEmpty)
    }

    private var bulkActionMenu: some View {
        Menu {
            ForEach(BulkAction.allCases) { action in
                Button(role: action.isDestructive ? ButtonRole.destructive : nil) {
                    if action.requiresConfirmation {
                        pendingBulkAction = action
                    } else {
                        perform(action)
                    }
                } label: {
                    Label(action.localizedName, systemImage: action.systemImage)
                }
            }
        } label: {
            Label("bulk.actions", systemImage: "ellipsis.circle")
        }
        .disabled(selection.isEmpty)
        .accessibilityLabel("bulk.actions")
    }

    private var selectionCountLabel: String {
        String(format: NSLocalizedString("bulk.selectedCountFormat", comment: ""), selection.count)
    }

    // MARK: Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(displayedItems) { item in
                    NavigationLink(destination: FoodDetailView(item: item).onDisappear { loadItems() }) {
                        FoodGridCell(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.large)
        }
        .refreshable { loadItems() }
    }

    // MARK: Filter Menu

    private var filterSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                Text(
                    String(
                        format: NSLocalizedString("filter.resultCountFormat", comment: ""),
                        displayedItems.count
                    )
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.trailing, AppSpacing.xSmall)

                if !searchText.isEmpty {
                    ActiveFilterChip(
                        title: String(
                            format: NSLocalizedString("filter.searchFormat", comment: ""),
                            searchText
                        ),
                        onRemove: { searchText = "" }
                    )
                }
                if filterOption != .all {
                    ActiveFilterChip(
                        title: filterOption.localizedName,
                        onRemove: { filterOption = .all }
                    )
                }
                if let selectedCategory {
                    ActiveFilterChip(
                        title: selectedCategory.localizedName,
                        onRemove: { self.selectedCategory = nil }
                    )
                }
                if let selectedLocation {
                    ActiveFilterChip(
                        title: selectedLocation.localizedName,
                        onRemove: { self.selectedLocation = nil }
                    )
                }
                if hasActiveFilters {
                    Button("button.clearFilters", action: clearFilters)
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
        }
        .background(.bar)
        .accessibilityElement(children: .contain)
    }

    private var filterMenu: some View {
        Menu {
            // Sort
            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        sortOptionRawValue = opt.rawValue
                    } label: {
                        if sortOption == opt {
                            Label(opt.localizedName, systemImage: "checkmark")
                        } else {
                            Text(opt.localizedName)
                        }
                    }
                }
            } label: {
                Label("menu.sort", systemImage: "arrow.up.arrow.down")
            }

            // Filter by status
            Menu {
                ForEach(FilterOption.allCases) { opt in
                    Button {
                        filterOption = opt
                    } label: {
                        if filterOption == opt {
                            Label(opt.localizedName, systemImage: "checkmark")
                        } else {
                            Text(opt.localizedName)
                        }
                    }
                }
            } label: {
                Label("menu.filter", systemImage: "line.3.horizontal.decrease.circle")
            }

            // Filter by category
            Menu {
                Button {
                    selectedCategory = nil
                } label: {
                    if selectedCategory == nil {
                        Label("filter.all", systemImage: "checkmark")
                    } else {
                        Text("filter.all")
                    }
                }
                ForEach(FoodCategory.allCases) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        if selectedCategory == cat {
                            Label(cat.localizedName, systemImage: "checkmark")
                        } else {
                            Text(cat.localizedName)
                        }
                    }
                }
            } label: {
                Label("menu.category", systemImage: "tag")
            }

            // Filter by location
            Menu {
                Button {
                    selectedLocation = nil
                } label: {
                    if selectedLocation == nil {
                        Label("filter.all", systemImage: "checkmark")
                    } else {
                        Text("filter.all")
                    }
                }
                ForEach(StorageLocation.allCases) { loc in
                    Button {
                        selectedLocation = loc
                    } label: {
                        if selectedLocation == loc {
                            Label(loc.localizedName, systemImage: "checkmark")
                        } else {
                            Text(loc.localizedName)
                        }
                    }
                }
            } label: {
                Label("menu.location", systemImage: "mappin")
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3")
        }
        .accessibilityLabel("button.filter")
    }

    private var filteredEmptyState: some View {
        VStack(spacing: AppSpacing.medium) {
            EmptyStateView(message: "empty.noFilteredItems", icon: "line.3.horizontal.decrease.circle")
            Button("button.clearFilters", action: clearFilters)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.large)
    }

    // MARK: Helpers

    private func loadItems() {
        do {
            items = try repository.fetchActive()
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func deleteItem(_ item: FoodItem) {
        let snapshot = FoodItemSnapshot(item: item)
        do {
            try repository.delete(item)
            loadItems()
            NotificationService.shared.refreshSchedule(using: repository)
            feedbackCenter.showUndo(
                message: String(
                    format: NSLocalizedString("feedback.deletedFormat", comment: ""),
                    snapshot.name
                )
            ) {
                do {
                    try repository.restore(snapshot)
                    loadItems()
                    NotificationService.shared.refreshSchedule(using: repository)
                } catch {
                    operationError = error.localizedDescription
                }
            }
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func markEaten(_ item: FoodItem) {
        let snapshot = FoodItemSnapshot(item: item)
        do {
            let record = try repository.archiveItemForUndo(item, status: .eaten)
            loadItems()
            NotificationService.shared.refreshSchedule(using: repository)
            feedbackCenter.showUndo(
                message: String(
                    format: NSLocalizedString("feedback.archivedFormat", comment: ""),
                    snapshot.name,
                    FoodStatus.eaten.localizedName
                )
            ) {
                do {
                    try repository.restoreArchivedItem(snapshot, removing: record)
                    loadItems()
                    NotificationService.shared.refreshSchedule(using: repository)
                } catch {
                    operationError = error.localizedDescription
                }
            }
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func clearFilters() {
        searchText = ""
        filterOption = .all
        selectedCategory = nil
        selectedLocation = nil
    }

    private func exitSelectionMode() {
        isSelecting = false
        selection.clear()
        pendingBulkAction = nil
    }

    private func perform(_ action: BulkAction) {
        let targets = selection.resolve(from: displayedItems)
        guard !targets.isEmpty else { return }

        do {
            let inventoryChanged: Bool
            switch action {
            case .markEaten:
                try repository.archiveItems(targets, status: .eaten)
                inventoryChanged = true
            case .markDiscarded:
                try repository.archiveItems(targets, status: .discarded)
                inventoryChanged = true
            case .addToShoppingList:
                try shoppingRepository.add(from: targets)
                inventoryChanged = false
            case .delete:
                try repository.deleteItems(targets)
                inventoryChanged = true
            }
            feedbackCenter.show(message: action.completionMessage(count: targets.count))
            loadItems()
            selection.retain(in: displayedItems)
            if selection.isEmpty { isSelecting = false }
            if inventoryChanged {
                NotificationService.shared.refreshSchedule(using: repository)
            }
        } catch {
            operationError = error.localizedDescription
        }
    }
}

// MARK: - FoodRowView

struct FoodRowView: View {
    let item: FoodItem

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            FoodThumbnailView(imageData: item.photoData, placeholder: item.categoryEnum.emoji)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(item.categoryEnum.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(item.quantity.formatted()) \(item.unit.localizedFoodUnit)  •  \(item.storageLocationEnum.localizedName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let exp = item.expirationDate {
                    Label {
                        Text(exp, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.footnote)
                    .foregroundStyle(expirationColor)
                }
            }

            Spacer()

            ExpirationBadge(state: item.expirationState)
                .padding(.top, 2)
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var expirationColor: Color {
        item.expirationState.tintColor
    }
}

// MARK: - FoodGridCell

struct FoodGridCell: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            FoodThumbnailView(
                imageData: item.photoData,
                placeholder: item.categoryEnum.emoji,
                size: 128,
                cornerRadius: AppCornerRadius.large
            )
            .frame(maxWidth: .infinity)

            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            Text(item.categoryEnum.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top) {
                Text("\(item.quantity.formatted()) \(item.unit.localizedFoodUnit)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                ExpirationBadge(state: item.expirationState)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(padding: AppSpacing.medium)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ExpirationBadge

struct ExpirationBadge: View {
    let state: ExpirationState

    var body: some View {
        switch state {
        case .noDate:
            EmptyView()
        default:
            StatusBadge(
                title: state.localizedLabel,
                systemImage: state.symbolName,
                tint: badgeColor
            )
        }
    }

    private var badgeColor: Color {
        state.tintColor
    }
}

private struct ActiveFilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: AppSpacing.xSmall) {
                Text(title)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.caption2.bold())
            }
            .font(.footnote.weight(.medium))
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("filter.removeHint")
    }
}

#Preview {
    FoodListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(CloudKitService.shared)
        .environmentObject(AppFeedbackCenter())
}
