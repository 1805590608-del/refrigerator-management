import SwiftUI

struct FoodDetailView: View {
    private let minimumQuantity = 0.1
    private let maximumQuantity = 9_999.0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: FoodItem

    @State private var showEdit = false
    @State private var showAddAgain = false
    @State private var activeAlert: FoodDetailAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                photoHero
                headerCard
                detailsCard

                if !item.notes.isEmpty {
                    notesCard
                }

                quantityAdjuster
                actionButtons
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.large)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Text("button.edit")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditFoodView(item: item)
        }
        .sheet(isPresented: $showAddAgain) {
            AddEditFoodView(prefill: FoodFormDraft(item: item))
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteConfirmation:
                Alert(
                    title: Text("alert.deleteTitle"),
                    message: Text("alert.deleteMessage"),
                    primaryButton: .destructive(Text("button.delete"), action: deleteItem),
                    secondaryButton: .cancel(Text("button.cancel"))
                )
            case .shoppingAdded(let name):
                Alert(
                    title: Text("shopping.addedTitle"),
                    message: Text(
                        String(
                            format: NSLocalizedString("shopping.addedFormat", comment: ""),
                            name
                        )
                    ),
                    dismissButton: .default(Text("button.ok"))
                )
            case .error(let message):
                Alert(
                    title: Text("alert.errorTitle"),
                    message: Text(message),
                    dismissButton: .default(Text("button.ok"))
                )
            }
        }
    }

    // MARK: - Photo Hero

    private var photoHero: some View {
        Group {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: AppSpacing.small) {
                    Text(item.categoryEnum.emoji)
                        .font(.system(size: 56))
                    Text(item.categoryEnum.localizedName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.xLarge, style: .continuous))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(item.name)
                        .font(.title2.weight(.semibold))
                    Text("\(item.categoryEnum.localizedName) • \(item.storageLocationEnum.localizedName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: AppSpacing.medium)
                ExpirationBadge(state: item.expirationState)
            }
        }
        .appCardStyle()
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "section.basicInfo")
            detailsGrid
        }
        .appCardStyle()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: "section.notes")
            Text(item.notes)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .appCardStyle()
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.medium), GridItem(.flexible(), spacing: AppSpacing.medium)], spacing: AppSpacing.medium) {
            DetailRow(label: "field.category", value: "\(item.categoryEnum.emoji) \(item.categoryEnum.localizedName)")
            DetailRow(label: "field.location", value: "\(item.storageLocationEnum.emoji) \(item.storageLocationEnum.localizedName)")
            DetailRow(label: "field.quantity", value: "\(item.quantity.formatted()) \(item.unit)")
            DetailRow(label: "field.purchaseDate", value: item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            if let exp = item.expirationDate {
                DetailRow(label: "field.expirationDate", value: exp.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    // MARK: - Quantity Adjuster

    private var quantityAdjuster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "section.quantity")

            HStack {
                Text("field.quantity")
                    .font(.headline)
                Spacer()
                Button {
                    adjustQuantity(by: -1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(item.quantity > minimumQuantity ? Color.accentColor : Color.secondary)
                }
                .disabled(item.quantity <= minimumQuantity)
                .accessibilityLabel("button.decreaseQuantity")

                Text("\(item.quantity.formatted()) \(item.unit)")
                    .font(.headline)
                    .frame(minWidth: 72, alignment: .center)

                Button {
                    adjustQuantity(by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(item.quantity < maximumQuantity ? Color.accentColor : Color.secondary)
                }
                .disabled(item.quantity >= maximumQuantity)
                .accessibilityLabel("button.increaseQuantity")
            }
        }
        .appCardStyle()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.medium) {
            Button {
                addToShoppingList()
            } label: {
                Label("button.addToShoppingList", systemImage: "cart.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(
                Text(
                    String(
                        format: NSLocalizedString("accessibility.addToShoppingFormat", comment: ""),
                        item.name
                    )
                )
            )

            Button {
                showAddAgain = true
            } label: {
                Label("button.addAgain", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(
                Text(
                    String(
                        format: NSLocalizedString("accessibility.addAgainFormat", comment: ""),
                        item.name
                    )
                )
            )

            HStack(spacing: AppSpacing.medium) {
                Button {
                    archive(as: .eaten)
                } label: {
                    Label("status.eaten", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: .systemGreen))
                .accessibilityLabel("button.markEaten")

                Button {
                    archive(as: .discarded)
                } label: {
                    Label("status.discarded", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: .systemOrange))
                .accessibilityLabel("button.markDiscarded")
            }

            Button(role: .destructive) {
                activeAlert = .deleteConfirmation
            } label: {
                Label("button.delete", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("button.delete")
        }
        .appCardStyle()
    }

    // MARK: - Helpers

    private func addToShoppingList() {
        do {
            try ShoppingRepository(context: modelContext).add(from: item)
            activeAlert = .shoppingAdded(item.name)
        } catch {
            activeAlert = .error(error.localizedDescription)
        }
    }

    private func adjustQuantity(by delta: Double) {
        let newQ = min(maximumQuantity, max(minimumQuantity, item.quantity + delta))
        let previousQuantity = item.quantity
        let previousUpdatedAt = item.updatedAt
        item.quantity = newQ
        item.updatedAt = Date()
        do {
            try FoodRepository(context: modelContext).save(item)
        } catch {
            item.quantity = previousQuantity
            item.updatedAt = previousUpdatedAt
            activeAlert = .error(error.localizedDescription)
        }
    }

    private func archive(as status: FoodStatus) {
        let repository = FoodRepository(context: modelContext)
        do {
            try repository.archiveItem(item, status: status)
            NotificationService.shared.refreshSchedule(using: repository)
            dismiss()
        } catch {
            activeAlert = .error(error.localizedDescription)
        }
    }

    private func deleteItem() {
        let repository = FoodRepository(context: modelContext)
        do {
            try repository.delete(item)
            NotificationService.shared.refreshSchedule(using: repository)
            dismiss()
        } catch {
            activeAlert = .error(error.localizedDescription)
        }
    }
}

private enum FoodDetailAlert: Identifiable {
    case deleteConfirmation
    case shoppingAdded(String)
    case error(String)

    var id: String {
        switch self {
        case .deleteConfirmation:
            "deleteConfirmation"
        case .shoppingAdded(let name):
            "shoppingAdded:\(name)"
        case .error(let message):
            "error:\(message)"
        }
    }
}

// MARK: - DetailRow

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(LocalizedStringKey(label))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        FoodDetailView(item: FoodItem(name: "Apple", category: .fruit, storageLocation: .fridge))
            .modelContainer(PersistenceController.preview.container)
    }
}
