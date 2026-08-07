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
                // Stats bar
                statsBar
                    .padding()
                    .background(Color(.systemBackground))

                // Range picker
                Picker("", selection: $selectedRange) {
                    ForEach(HistoryViewModel.TimeRange.allCases) { range in
                        Text(range.localizedName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

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
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.history")
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
        HStack(spacing: 20) {
            VStack {
                Text("\(filtered.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("history.total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(filtered.filter { $0.finalStatusEnum == .eaten }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                Text("history.eaten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(filtered.filter { $0.finalStatusEnum == .discarded || $0.finalStatusEnum == .expired }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                Text("history.wasted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        HStack(spacing: 12) {
            if let data = record.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(record.categoryEnum.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.foodName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(record.archivedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(record.finalStatusEnum.localizedName)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch record.finalStatusEnum {
        case .eaten:    return .green
        case .discarded: return .orange
        case .expired:  return .red
        default:        return .gray
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(PersistenceController.preview.container)
}
