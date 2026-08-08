import Foundation

/// Pure aggregation helpers for waste analytics.
/// All functions are static and side-effect-free so they are easy to unit-test.
enum WasteInsights {

    // MARK: - Helpers

    private static func wastedRecords(in records: [HistoryRecord]) -> [HistoryRecord] {
        records.filter {
            $0.finalStatusEnum == .discarded || $0.finalStatusEnum == .expired
        }
    }

    // MARK: - Public API

    /// The food category with the highest waste count, or `nil` when there is no waste.
    static func topCategory(in records: [HistoryRecord]) -> FoodCategory? {
        let wasted = wastedRecords(in: records)
        guard !wasted.isEmpty else { return nil }
        let counts = Dictionary(grouping: wasted, by: \.category)
            .mapValues(\.count)
        return counts
            .max(by: { $0.value < $1.value })
            .flatMap { FoodCategory(rawValue: $0.key) }
    }

    /// The storage location with the highest waste count, or `nil` when there is no waste.
    static func topLocation(in records: [HistoryRecord]) -> StorageLocation? {
        let wasted = wastedRecords(in: records)
        guard !wasted.isEmpty else { return nil }
        let counts = Dictionary(grouping: wasted, by: \.storageLocation)
            .mapValues(\.count)
        return counts
            .max(by: { $0.value < $1.value })
            .flatMap { StorageLocation(rawValue: $0.key) }
    }

    /// Fraction of archived items that were wasted (0–1), or `nil` when there are no records.
    static func wasteRatio(in records: [HistoryRecord]) -> Double? {
        guard !records.isEmpty else { return nil }
        let wasted = wastedRecords(in: records).count
        return Double(wasted) / Double(records.count)
    }
}
