import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var records: [HistoryRecord] = []
    @State private var selectedRange: HistoryViewModel.TimeRange = .month
    @State private var showClearAlert = false

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
                            HistoryRowView(record: record)
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
                        showClearAlert = true
                    }
                    .disabled(records.isEmpty)
                }
            }
            .alert("alert.clearHistoryTitle", isPresented: $showClearAlert) {
                Button("button.clearAll", role: .destructive) { clearAll() }
                Button("button.cancel", role: .cancel) {}
            } message: {
                Text("alert.clearHistoryMessage")
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

    private func deleteRecord(_ record: HistoryRecord) {
        try? repo.deleteHistory(record)
        loadRecords()
    }

    private func clearAll() {
        try? repo.clearAllHistory()
        loadRecords()
    }
}

// MARK: - HistoryRowView

struct HistoryRowView: View {
    let record: HistoryRecord

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            FoodThumbnailView(imageData: record.photoData, placeholder: record.categoryEnum.emoji, size: 52)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(record.foodName)
                    .font(.headline)
                Text(record.archivedAt, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(
                title: record.finalStatusEnum.localizedName,
                systemImage: record.finalStatusEnum.symbolName,
                tint: statusColor
            )
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        record.finalStatusEnum.tintColor
    }
}

#Preview {
    HistoryView()
        .modelContainer(PersistenceController.preview.container)
}
