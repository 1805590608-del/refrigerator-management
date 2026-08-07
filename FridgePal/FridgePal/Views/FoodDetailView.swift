import SwiftUI

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"

    let item: FoodItem

    @State private var showEdit = false
    @State private var showDeleteAlert = false

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
        .alert("alert.deleteTitle", isPresented: $showDeleteAlert) {
            Button("button.delete", role: .destructive) { deleteItem() }
            Button("button.cancel", role: .cancel) {}
        } message: {
            Text("alert.deleteMessage")
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
                        .foregroundStyle(item.quantity > 1 ? .accentColor : .secondary)
                }
                .disabled(item.quantity <= 1)
                .accessibilityLabel("button.decreaseQuantity")

                Text("\(item.quantity.formatted()) \(item.unit)")
                    .font(.headline)
                    .frame(minWidth: 72, alignment: .center)

                Button {
                    adjustQuantity(by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }
                .accessibilityLabel("button.increaseQuantity")
            }
        }
        .appCardStyle()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.medium) {
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
                showDeleteAlert = true
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

    private func adjustQuantity(by delta: Double) {
        let newQ = max(1, item.quantity + delta)
        item.quantity = newQ
        item.updatedAt = Date()
        try? FoodRepository(context: modelContext).save(item)
    }

    private func archive(as status: FoodStatus) {
        let reminderDays = reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        NotificationService.shared.cancelReminders(for: item, advanceDays: reminderDays)
        try? FoodRepository(context: modelContext).archiveItem(item, status: status)
        dismiss()
    }

    private func deleteItem() {
        let reminderDays = reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        NotificationService.shared.cancelReminders(for: item, advanceDays: reminderDays)
        try? FoodRepository(context: modelContext).delete(item)
        dismiss()
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
