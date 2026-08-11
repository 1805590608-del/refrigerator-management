import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter
    @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var items: [ShoppingItem]
    @State private var errorMessage: String?
    @State private var showAddItem = false
    @State private var itemToAddToFridge: ShoppingItem?

    private var itemsToBuy: [ShoppingItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [ShoppingItem] {
        items.filter(\.isCompleted)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(message: "empty.noShoppingItems", icon: "cart")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !itemsToBuy.isEmpty {
                            shoppingSection(title: "shopping.toBuy", items: itemsToBuy)
                        }

                        if !completedItems.isEmpty {
                            completedSection
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.shopping")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("button.addShoppingItem")
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddShoppingItemView()
            }
            .sheet(item: $itemToAddToFridge) { item in
                AddEditFoodView(
                    prefill: FoodFormDraft(shoppingItem: item),
                    onSaved: { moveToFridge(item) }
                )
            }
            .alert("alert.errorTitle", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("button.ok") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func shoppingSection(
        title: LocalizedStringKey,
        items: [ShoppingItem]
    ) -> some View {
        Section(title) {
            ForEach(items) { item in
                ShoppingItemRowView(
                    item: item,
                    toggleCompletion: { toggleCompletion(for: item) }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(item)
                    } label: {
                        Label("button.delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        Section {
            ForEach(completedItems) { item in
                ShoppingItemRowView(
                    item: item,
                    toggleCompletion: { toggleCompletion(for: item) },
                    addToFridge: { itemToAddToFridge = item }
                )
                .swipeActions(edge: .leading) {
                    Button {
                        itemToAddToFridge = item
                    } label: {
                        Label("shopping.addToFridge", systemImage: "refrigerator.fill")
                    }
                    .tint(.accentColor)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(item)
                    } label: {
                        Label("button.delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Text("shopping.completed")
                Spacer()
                Button("shopping.clearCompleted", action: clearCompleted)
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
            }
        } footer: {
            Text("shopping.completedFooter")
        }
    }

    private func toggleCompletion(for item: ShoppingItem) {
        do {
            try ShoppingRepository(context: modelContext)
                .setCompleted(item, isCompleted: !item.isCompleted)
            UISelectionFeedbackGenerator().selectionChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: ShoppingItem) {
        let snapshot = ShoppingItemSnapshot(item: item)
        do {
            try ShoppingRepository(context: modelContext).delete(item)
            feedbackCenter.showUndo(
                message: String(
                    format: NSLocalizedString("feedback.deletedFormat", comment: ""),
                    snapshot.name
                )
            ) {
                do {
                    try ShoppingRepository(context: modelContext).restore([snapshot])
                } catch {
                    feedbackCenter.showError(message: error.localizedDescription)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearCompleted() {
        let snapshots = completedItems.map(ShoppingItemSnapshot.init(item:))
        do {
            try ShoppingRepository(context: modelContext).clearCompleted()
            feedbackCenter.showUndo(
                message: NSLocalizedString("feedback.clearedCompleted", comment: "")
            ) {
                do {
                    try ShoppingRepository(context: modelContext).restore(snapshots)
                } catch {
                    feedbackCenter.showError(message: error.localizedDescription)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveToFridge(_ item: ShoppingItem) {
        do {
            try ShoppingRepository(context: modelContext).delete(item)
            feedbackCenter.show(
                message: String(
                    format: NSLocalizedString("shopping.movedToFridgeFormat", comment: ""),
                    item.name
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter

    @State private var name = ""
    @State private var category: FoodCategory = .other
    @State private var preferredQuantity = 1.0
    @State private var unit = "item"
    @State private var nameError: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        TextField("field.name", text: $name)
                            .autocorrectionDisabled()
                        if let nameError {
                            Text(nameError)
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .systemRed))
                        }
                    }

                    Picker("field.category", selection: $category) {
                        ForEach(FoodCategory.allCases) { category in
                            Text("\(category.emoji)  \(category.localizedName)")
                                .tag(category)
                        }
                    }
                } header: {
                    Text("section.basicInfo")
                        .textCase(nil)
                        .font(.footnote.weight(.semibold))
                }

                Section {
                    Stepper(value: $preferredQuantity, in: quantityRange, step: quantityStep) {
                        HStack {
                            Text("field.quantity")
                            Spacer()
                            Text(preferredQuantity.formatted())
                        }
                    }

                    Picker("field.unit", selection: $unit) {
                        ForEach(FoodUnit.allCases) { unit in
                            Text(unit.localizedName)
                                .tag(unit.rawValue)
                        }
                    }
                } header: {
                    Text("section.quantity")
                        .textCase(nil)
                        .font(.footnote.weight(.semibold))
                }
            }
            .navigationTitle("nav.addShoppingItem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button.save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .alert("alert.errorTitle", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("button.ok") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .onChange(of: unit) { _, _ in
                preferredQuantity = max(preferredQuantity, selectedUnit.minimumQuantity)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameError = NSLocalizedString("validation.nameRequired", comment: "")
            return
        }

        nameError = nil
        do {
            try ShoppingRepository(context: modelContext).add(
                name: trimmedName,
                category: category,
                preferredQuantity: preferredQuantity,
                unit: unit
            )
            feedbackCenter.show(
                message: String(
                    format: NSLocalizedString("shopping.addedFormat", comment: ""),
                    trimmedName
                )
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var quantityStep: Double {
        selectedUnit.quantityStep
    }

    private var quantityRange: ClosedRange<Double> {
        selectedUnit.minimumQuantity...9_999
    }

    private var selectedUnit: FoodUnit {
        FoodUnit(rawValue: unit) ?? .item
    }
}

private struct ShoppingItemRowView: View {
    let item: ShoppingItem
    let toggleCompletion: () -> Void
    var addToFridge: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: toggleCompletion) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(completionAccessibilityLabel)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                Text("\(item.categoryEnum.localizedName) • \(item.preferredQuantity.formatted()) \(item.unit.localizedFoodUnit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if let addToFridge {
                Button(action: addToFridge) {
                    Image(systemName: "refrigerator.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("shopping.addToFridge")
            } else {
                Text(item.categoryEnum.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var completionAccessibilityLabel: Text {
        let key = item.isCompleted
            ? "accessibility.markNeededFormat"
            : "accessibility.markPurchasedFormat"
        return Text(
            String(
                format: NSLocalizedString(key, comment: ""),
                item.name
            )
        )
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(AppFeedbackCenter())
}
