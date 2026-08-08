import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var items: [ShoppingItem]
    @State private var errorMessage: String?

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
