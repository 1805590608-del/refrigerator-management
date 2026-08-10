import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var items: [ShoppingItem]
    @State private var errorMessage: String?
    @State private var showAddItem = false

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
                            shoppingSection(title: "shopping.completed", items: completedItems)
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
                ShoppingItemRowView(item: item) {
                    toggleCompletion(for: item)
                }
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

    private func toggleCompletion(for item: ShoppingItem) {
        do {
            try ShoppingRepository(context: modelContext)
                .setCompleted(item, isCompleted: !item.isCompleted)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: ShoppingItem) {
        do {
            try ShoppingRepository(context: modelContext).delete(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddShoppingItemView: View {
    private let units = ["item", "box", "bag", "bottle", "g", "kg", "oz", "lb", "L", "mL", "pack", "can", "piece"]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                    Stepper(value: $preferredQuantity, in: 0.1...9999, step: 1) {
                        HStack {
                            Text("field.quantity")
                            Spacer()
                            Text(preferredQuantity.formatted())
                        }
                    }

                    Picker("field.unit", selection: $unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(NSLocalizedString("unit.\(unit)", comment: unit))
                                .tag(unit)
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
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct ShoppingItemRowView: View {
    let item: ShoppingItem
    let toggleCompletion: () -> Void

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

                Text("\(item.categoryEnum.localizedName) • \(item.preferredQuantity.formatted()) \(item.unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Text(item.categoryEnum.emoji)
                .font(.title2)
                .accessibilityHidden(true)
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
}
