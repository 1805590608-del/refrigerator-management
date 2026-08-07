import SwiftUI
import SwiftData

struct FoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferGridView") private var preferGridView: Bool = false
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"
    @State private var items: [FoodItem] = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .expirationDate
    @State private var filterOption: FilterOption = .all
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedLocation: StorageLocation? = nil
    @State private var showAddFood = false
    @State private var itemToDelete: FoodItem? = nil
    @State private var showDeleteAlert = false

    private var reminderDays: [Int] {
        reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

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
                } else if preferGridView {
                    gridView
                } else {
                    listView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.list")
            .searchable(text: $searchText, prompt: "search.prompt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            preferGridView.toggle()
                        } label: {
                            Image(systemName: preferGridView ? "list.bullet" : "square.grid.2x2")
                        }
                        .accessibilityLabel(preferGridView ? "button.listView" : "button.gridView")

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
            .onAppear { loadItems() }
        }
    }

    // MARK: List View

    private var listView: some View {
        List {
            ForEach(displayedItems) { item in
                NavigationLink(destination: FoodDetailView(item: item).onDisappear { loadItems() }) {
                    FoodRowView(item: item)
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
                    .tint(.green)
                }
            }
        }
        .listStyle(.insetGrouped)
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
            .padding()
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
        NotificationService.shared.cancelReminders(for: item, advanceDays: reminderDays)
        try? repository.delete(item)
        loadItems()
    }

    private func markEaten(_ item: FoodItem) {
        NotificationService.shared.cancelReminders(for: item, advanceDays: reminderDays)
        try? repository.archiveItem(item, status: .eaten)
        loadItems()
    }
}

// MARK: - FoodRowView

struct FoodRowView: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let data = item.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(item.categoryEnum.emoji)
                        .font(.title2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(item.quantity.formatted()) \(item.unit)  •  \(item.storageLocationEnum.localizedName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let exp = item.expirationDate {
                    Text(exp, style: .date)
                        .font(.caption)
                        .foregroundStyle(expirationColor)
                }
            }

            Spacer()

            ExpirationBadge(state: item.expirationState)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var expirationColor: Color {
        switch item.expirationState {
        case .fresh:        return .green
        case .expiringSoon: return .orange
        case .expired:      return .red
        case .noDate:       return .secondary
        }
    }
}

// MARK: - FoodGridCell

struct FoodGridCell: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let data = item.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(item.categoryEnum.emoji)
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack {
                Text("\(item.quantity.formatted()) \(item.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ExpirationBadge(state: item.expirationState)
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
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
            Text(state.localizedLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.15), in: Capsule())
                .foregroundStyle(badgeColor)
        }
    }

    private var badgeColor: Color {
        switch state {
        case .fresh:        return .green
        case .expiringSoon: return .orange
        case .expired:      return .red
        case .noDate:       return .gray
        }
    }
}

#Preview {
    FoodListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(CloudKitService.shared)
}
