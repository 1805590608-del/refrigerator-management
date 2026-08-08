import SwiftUI
import SwiftData

struct FoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferGridView") private var preferGridView: Bool = false
    @State private var items: [FoodItem] = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .expirationDate
    @State private var filterOption: FilterOption = .all
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedLocation: StorageLocation? = nil
    @State private var showAddFood = false
    @State private var itemToDelete: FoodItem? = nil
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selection = BulkSelection()
    @State private var pendingBulkAction: BulkAction? = nil
    @State private var bulkResultMessage: String? = nil

    private var repository: FoodRepository { FoodRepository(context: modelContext) }

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

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(message: "empty.noItems", icon: "refrigerator")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if preferGridView && !isSelecting {
                    gridView
                } else {
                    listView
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
            .alert(
                "bulk.doneTitle",
                isPresented: Binding(
                    get: { bulkResultMessage != nil },
                    set: { if !$0 { bulkResultMessage = nil } }
                )
            ) {
                Button("button.ok") { bulkResultMessage = nil }
            } message: {
                Text(bulkResultMessage ?? "")
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
    }

    // MARK: Filter Menu

    private var filterMenu: some View {
        Menu {
            // Sort
            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        sortOption = opt
                    } label: {
                        Label(opt.localizedName, systemImage: sortOption == opt ? "checkmark" : "")
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
                        Label(opt.localizedName, systemImage: filterOption == opt ? "checkmark" : "")
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
                    Label("filter.all", systemImage: selectedCategory == nil ? "checkmark" : "")
                }
                ForEach(FoodCategory.allCases) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Label(cat.localizedName, systemImage: selectedCategory == cat ? "checkmark" : "")
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
                    Label("filter.all", systemImage: selectedLocation == nil ? "checkmark" : "")
                }
                ForEach(StorageLocation.allCases) { loc in
                    Button {
                        selectedLocation = loc
                    } label: {
                        Label(loc.localizedName, systemImage: selectedLocation == loc ? "checkmark" : "")
                    }
                }
            } label: {
                Label("menu.location", systemImage: "mappin")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("button.filter")
    }

    // MARK: Helpers

    private func loadItems() {
        items = (try? repository.fetchActive()) ?? []
    }

    private func deleteItem(_ item: FoodItem) {
        try? repository.delete(item)
        loadItems()
        NotificationService.shared.refreshSchedule(using: repository)
    }

    private func markEaten(_ item: FoodItem) {
        try? repository.archiveItem(item, status: .eaten)
        loadItems()
        NotificationService.shared.refreshSchedule(using: repository)
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
            switch action {
            case .markEaten:
                try repository.archiveItems(targets, status: .eaten)
            case .markDiscarded:
                try repository.archiveItems(targets, status: .discarded)
            case .addToShoppingList:
                try ShoppingRepository(context: modelContext).add(from: targets)
            case .delete:
                try repository.deleteItems(targets)
            }
            bulkResultMessage = String(
                format: NSLocalizedString("bulk.done.\(action.rawValue)Format", comment: ""),
                targets.count
            )
        } catch {
            bulkResultMessage = error.localizedDescription
        }

        loadItems()
        selection.retain(in: displayedItems)
        if selection.isEmpty { isSelecting = false }
        NotificationService.shared.refreshSchedule(using: repository)
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
                Text("\(item.quantity.formatted()) \(item.unit)  •  \(item.storageLocationEnum.localizedName)")
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
                Text("\(item.quantity.formatted()) \(item.unit)")
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

#Preview {
    FoodListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(CloudKitService.shared)
}
