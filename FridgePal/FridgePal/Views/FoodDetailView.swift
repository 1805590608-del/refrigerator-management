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
            VStack(alignment: .leading, spacing: 0) {
                // Photo hero
                photoHero

                // Info card
                VStack(alignment: .leading, spacing: 16) {
                    // Name + badge
                    HStack {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        ExpirationBadge(state: item.expirationState)
                    }

                    Divider()

                    // Details grid
                    detailsGrid

                    if !item.notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("field.notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.notes)
                                .font(.body)
                        }
                    }

                    Divider()

                    // Quantity adjuster
                    quantityAdjuster

                    Divider()

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
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
            if let data = item.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()
            } else {
                Text(item.categoryEnum.emoji)
                    .font(.system(size: 60))
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color(.secondarySystemBackground))
            }
        }
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
        HStack {
            Text("field.quantity")
                .fontWeight(.medium)
            Spacer()
            Button {
                adjustQuantity(by: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(item.quantity > 1 ? .blue : .secondary)
            }
            .disabled(item.quantity <= 1)
            .accessibilityLabel("button.decreaseQuantity")

            Text("\(item.quantity.formatted()) \(item.unit)")
                .font(.headline)
                .frame(minWidth: 60, alignment: .center)

            Button {
                adjustQuantity(by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel("button.increaseQuantity")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    archive(as: .eaten)
                } label: {
                    Label("status.eaten", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("button.markEaten")

                Button {
                    archive(as: .discarded)
                } label: {
                    Label("status.discarded", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label))
                .font(.caption)
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
