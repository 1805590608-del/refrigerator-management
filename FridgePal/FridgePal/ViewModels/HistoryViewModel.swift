import Foundation
import SwiftData

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var records: [HistoryRecord] = []
    @Published var selectedTimeRange: TimeRange = .month
    @Published var errorMessage: String?

    private let repository: FoodRepositoryProtocol

    enum TimeRange: String, CaseIterable, Identifiable {
        case week  = "week"
        case month = "month"
        case year  = "year"
        case all   = "all"

        var id: String { rawValue }
        var localizedName: String { NSLocalizedString("timeRange.\(rawValue)", comment: "") }

        var days: Int? {
            switch self {
            case .week:  return 7
            case .month: return 30
            case .year:  return 365
            case .all:   return nil
            }
        }
    }

    init(repository: FoodRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        do {
            records = try repository.fetchHistory()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var filteredRecords: [HistoryRecord] {
        guard let days = selectedTimeRange.days else { return records }
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) else { return records }
        return records.filter { $0.archivedAt >= cutoff }
    }

    var discardedCount: Int { filteredRecords.filter { $0.finalStatusEnum == .discarded || $0.finalStatusEnum == .expired }.count }
    var eatenCount: Int     { filteredRecords.filter { $0.finalStatusEnum == .eaten }.count }

    // MARK: - Waste Insights

    /// Fraction of archived items that were wasted (0–1), or nil when there are no records.
    var wasteRatio: Double? {
        WasteInsights.wasteRatio(in: filteredRecords)
    }

    /// The food category wasted most often in the selected time range, or nil when nothing was wasted.
    var mostWastedCategory: FoodCategory? {
        WasteInsights.topCategory(in: filteredRecords)
    }

    /// The storage location whose items are wasted most often, or nil when nothing was wasted.
    var mostWastedLocation: StorageLocation? {
        WasteInsights.topLocation(in: filteredRecords)
    }

    func delete(_ record: HistoryRecord) {
        do {
            try repository.deleteHistory(record)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAll() {
        do {
            try repository.clearAllHistory()
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
