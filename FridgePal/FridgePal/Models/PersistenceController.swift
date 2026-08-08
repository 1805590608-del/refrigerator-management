import Foundation
import SwiftData
import CloudKit

// MARK: - Persistence Container

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: ModelContainer

    private init(inMemory: Bool = false) {
        let schema = Schema([FoodItem.self, HistoryRecord.self, ShoppingItem.self])

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Use CloudKit private database for sync
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.fridgepal.app")
            )
        }

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to local-only if CloudKit unavailable
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Cannot create ModelContainer: \(error)")
            }
        }
    }
}
