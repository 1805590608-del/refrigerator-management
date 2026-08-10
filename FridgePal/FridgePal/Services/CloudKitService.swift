import Foundation
import CloudKit
import Combine

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
    case notLoggedIn
}

// MARK: - iCloud Service

@MainActor
final class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    @Published var syncStatus: SyncStatus = .idle
    @Published var isICloudAvailable: Bool = false

    private var container: CKContainer {
        CKContainer(identifier: "iCloud.com.fridgepal.app")
    }

    private init() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        Task { await checkAccountStatus() }
    }

    func checkAccountStatus() async {
#if targetEnvironment(simulator)
        isICloudAvailable = false
        syncStatus = .error(NSLocalizedString("icloud.simulatorUnavailable", comment: ""))
#else
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                isICloudAvailable = true
                syncStatus = .idle
            case .noAccount:
                isICloudAvailable = false
                syncStatus = .notLoggedIn
            default:
                isICloudAvailable = false
                syncStatus = .error(NSLocalizedString("icloud.unavailable", comment: ""))
            }
        } catch {
            isICloudAvailable = false
            syncStatus = .error(error.localizedDescription)
        }
#endif
    }

    func markSyncing() { syncStatus = .syncing }
    func markSynced() { syncStatus = .synced }
    func markError(_ message: String) { syncStatus = .error(message) }
}
