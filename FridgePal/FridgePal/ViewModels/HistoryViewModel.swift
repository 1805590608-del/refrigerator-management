import Foundation
import SwiftData

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var records: [HistoryRecord] = []
    @Published var selectedTimeRange: TimeRange = .month

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
        } catch {
            records = []
        }
    }

    var filteredRecords: [HistoryRecord] {
        guard let days = selectedTimeRange.days else { return records }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return records.filter { $0.archivedAt >= cutoff }
    }

    var discardedCount: Int { filteredRecords.filter { $0.finalStatusEnum == .discarded || $0.finalStatusEnum == .expired }.count }
    var eatenCount: Int     { filteredRecords.filter { $0.finalStatusEnum == .eaten }.count }

    func delete(_ record: HistoryRecord) {
        try? repository.deleteHistory(record)
        load()
    }

    func clearAll() {
        try? repository.clearAllHistory()
        load()
    }
}
