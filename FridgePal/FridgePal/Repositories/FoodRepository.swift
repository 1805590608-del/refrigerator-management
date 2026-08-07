import Foundation
import SwiftData

// MARK: - Food Repository Protocol

protocol FoodRepositoryProtocol {
    func fetchAll() throws -> [FoodItem]
    func fetchActive() throws -> [FoodItem]
    func fetchHistory() throws -> [HistoryRecord]
    func save(_ item: FoodItem) throws
    func delete(_ item: FoodItem) throws
    func archiveItem(_ item: FoodItem, status: FoodStatus) throws
    func deleteHistory(_ record: HistoryRecord) throws
    func clearAllHistory() throws
}

// MARK: - Food Repository

final class FoodRepository: FoodRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func fetchActive() throws -> [FoodItem] {
        let active = FoodStatus.active.rawValue
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.status == active },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchHistory() throws -> [HistoryRecord] {
        let descriptor = FetchDescriptor<HistoryRecord>(sortBy: [SortDescriptor(\.archivedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func save(_ item: FoodItem) throws {
        item.updatedAt = Date()
        context.insert(item)
        try context.save()
    }

    func delete(_ item: FoodItem) throws {
        context.delete(item)
        try context.save()
    }

    func archiveItem(_ item: FoodItem, status: FoodStatus) throws {
        let record = HistoryRecord(from: item, finalStatus: status)
        context.insert(record)
        context.delete(item)
        try context.save()
    }

    func deleteHistory(_ record: HistoryRecord) throws {
        context.delete(record)
        try context.save()
    }

    func clearAllHistory() throws {
        let records = try fetchHistory()
        for r in records { context.delete(r) }
        try context.save()
    }
}
