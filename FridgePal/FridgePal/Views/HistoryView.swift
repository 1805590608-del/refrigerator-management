import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var records: [HistoryRecord] = []
    @State private var selectedRange: HistoryViewModel.TimeRange = .month
    @State private var recordToRepeat: HistoryRecord?
    @State private var activeAlert: HistoryAlert?

    private var repo: FoodRepository { FoodRepository(context: modelContext) }

    private var filtered: [HistoryRecord] {
        guard let days = selectedRange.days else { return records }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return records.filter { $0.archivedAt >= cutoff }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statsBar
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.top, AppSpacing.large)

                Picker("", selection: $selectedRange) {
                    ForEach(HistoryViewModel.TimeRange.allCases) { range in
                        Text(range.localizedName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)

                if filtered.isEmpty {
                    EmptyStateView(message: "empty.noHistory", icon: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { record in
                            HistoryRowView(
                                record: record,
                                repeatAction: { recordToRepeat = record },
                                shoppingAction: { addToShoppingList(record) }
                            )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteRecord(record)
                                    } label: {
                                        Label("button.delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("nav.history")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button.clearAll", role: .destructive) {
                        activeAlert = .clearConfirmation
                    }
                    .disabled(records.isEmpty)
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .clearConfirmation:
                    Alert(
                        title: Text("alert.clearHistoryTitle"),
                        message: Text("alert.clearHistoryMessage"),
                        primaryButton: .destructive(Text("button.clearAll"), action: clearAll),
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
            .sheet(item: $recordToRepeat) { record in
                AddEditFoodView(prefill: FoodFormDraft(historyRecord: record))
            }
            .onAppear { loadRecords() }
        }
    }

    private var statsBar: some View {
        HStack(spacing: AppSpacing.large) {
            VStack {
                Text("\(filtered.count)")
                    .font(.title2.weight(.semibold))
                Text("history.total")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(filtered.filter { $0.finalStatusEnum == .eaten }.count)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .systemGreen))
                Text("history.eaten")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(filtered.filter { $0.finalStatusEnum == .discarded || $0.finalStatusEnum == .expired }.count)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .systemRed))
                Text("history.wasted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
        .accessibilityElement(children: .combine)
    }

    private func loadRecords() {
        records = (try? repo.fetchHistory()) ?? []
    }

    private func addToShoppingList(_ record: HistoryRecord) {
        do {
            try ShoppingRepository(context: modelContext).add(from: record)
            activeAlert = .shoppingAdded(record.foodName)
        } catch {
            activeAlert = .error(error.localizedDescription)
        }
    }

    private func deleteRecord(_ record: HistoryRecord) {
        try? repo.deleteHistory(record)
        loadRecords()
    }

    private func clearAll() {
        try? repo.clearAllHistory()
        loadRecords()
    }
}

private enum HistoryAlert: Identifiable {
    case clearConfirmation
    case shoppingAdded(String)
    case error(String)

    var id: String {
        switch self {
        case .clearConfirmation:
            "clearConfirmation"
        case .shoppingAdded(let name):
            "shoppingAdded:\(name)"
        case .error(let message):
            "error:\(message)"
        }
    }
}

// MARK: - HistoryRowView

struct HistoryRowView: View {
    let record: HistoryRecord
    let repeatAction: () -> Void
    let shoppingAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                FoodThumbnailView(imageData: record.photoData, placeholder: record.categoryEnum.emoji, size: 52)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(record.foodName)
                        .font(.headline)
                    Text(record.archivedAt, style: .date)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.small) {
                StatusBadge(
                    title: record.finalStatusEnum.localizedName,
                    systemImage: record.finalStatusEnum.symbolName,
                    tint: statusColor
                )

                Button(action: shoppingAction) {
                    Label("button.addToShoppingList", systemImage: "cart.badge.plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    Text(
                        String(
                            format: NSLocalizedString("accessibility.addToShoppingFormat", comment: ""),
                            record.foodName
                        )
                    )
                )

                Button(action: repeatAction) {
                    Label("button.addAgain", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    Text(
                        String(
                            format: NSLocalizedString("accessibility.addAgainFormat", comment: ""),
                            record.foodName
                        )
                    )
                )
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var statusColor: Color {
        record.finalStatusEnum.tintColor
    }
}

#Preview {
    HistoryView()
        .modelContainer(PersistenceController.preview.container)
}
