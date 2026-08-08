# FridgePal — Refrigerator Food Management iOS App

A full-featured iOS app for tracking household food inventory, expiration dates, and consumption. Built with SwiftUI + SwiftData + CloudKit.

---

## Features

| Feature | Details |
|---|---|
| **Home Dashboard** | Prioritized “Expired Now” and “Use Soon” actions with direct item drill-down, plus summary counts, recent items, and location breakdown |
| **Food List** | List/grid toggle, search, filter by status/category/location, sort by date/name |
| **Add / Edit Food** | Camera or photo library, name, category, location, quantity, unit, purchase/expiry dates, notes |
| **Quick Add** | Add an active item again from inventory details or history with every field prefilled and editable |
| **Shopping List** | Save active or archived foods to buy again; mark entries purchased, move them back to “To Buy,” or remove them |
| **Food Detail** | Full info view, quantity ±1 adjuster, mark eaten/discarded, delete with confirmation |
| **Expiration Reminders** | Local push notifications 1/3/7 days before expiry, configurable in Settings |
| **iCloud Sync** | SwiftData + CloudKit private database; offline-first, auto-sync on reconnect |
| **History** | Eaten/discarded/expired archive; statistics by time range; bulk clear |
| **Settings** | Notification toggles, iCloud status check, list/grid preference, appearance |
| **Localization** | English (en) + Simplified Chinese (zh-Hans) |
| **Accessibility** | VoiceOver labels, Dynamic Type, Dark Mode |

---

## Project Structure

```
FridgePal/
├── FridgePal.xcodeproj/
└── FridgePal/
    ├── FridgePalApp.swift          # App entry point
    ├── Info.plist                  # Privacy usage strings, bundle config
    ├── Assets.xcassets/
    ├── Models/
    │   ├── FoodItem.swift          # @Model — main food entity + enums
    │   ├── HistoryRecord.swift     # @Model — archived food records
    │   ├── ShoppingItem.swift      # @Model — independent repurchase snapshots
    │   └── PersistenceController.swift  # ModelContainer + CloudKit setup
    ├── Repositories/
    │   ├── FoodRepository.swift    # Inventory CRUD + archive operations
    │   └── ShoppingRepository.swift # Shopping-list persistence
    ├── Services/
    │   ├── NotificationService.swift   # Local push notification scheduling
    │   ├── CloudKitService.swift       # iCloud account status + sync state
    │   └── ImageService.swift          # Photo resize/compress (max 1600px, JPEG 0.75)
    ├── ViewModels/
    │   ├── HomeViewModel.swift
    │   ├── FoodListViewModel.swift
    │   ├── AddEditFoodViewModel.swift
    │   └── HistoryViewModel.swift
    ├── Views/
    │   ├── ContentView.swift       # TabView root
    │   ├── HomeView.swift          # Dashboard
    │   ├── FoodListView.swift      # List + grid + swipe actions
    │   ├── AddEditFoodView.swift   # Form with camera/photo picker
    │   ├── FoodDetailView.swift    # Detail + actions
    │   ├── ShoppingListView.swift  # To-buy and purchased entries
    │   ├── HistoryView.swift       # Archive + statistics
    │   └── SettingsView.swift
    └── Resources/
        ├── en.lproj/Localizable.strings
        └── zh-Hans.lproj/Localizable.strings
FridgePalTests/
└── FridgePalTests.swift            # Unit tests
```

---

## Data Model

### FoodItem (`@Model`)
| Field | Type | Notes |
|---|---|---|
| id | UUID | `@Attribute(.unique)` |
| name | String | |
| category | String | `FoodCategory` rawValue |
| storageLocation | String | `StorageLocation` rawValue |
| quantity | Double | |
| unit | String | |
| purchaseDate | Date | |
| expirationDate | Date? | |
| photoData | Data? | `@Attribute(.externalStorage)` — syncs via CloudKit |
| notes | String | |
| status | String | `FoodStatus` rawValue |
| createdAt | Date | |
| updatedAt | Date | Used for conflict resolution |

### HistoryRecord (`@Model`)
Archived snapshot of a consumed/discarded/expired food item.

### ShoppingItem (`@Model`)
Independent repurchase snapshot containing the food name, category, preferred quantity, and unit. Completion timestamps and `updatedAt` support reversible purchased state and normal SwiftData/CloudKit persistence without retaining a relationship to an active or archived item.

### Shopping / Buy-Again Workflow

1. From an active food's detail screen, tap **Add to Shopping List**.
2. From History, tap **Add to Shopping List** on any consumed or discarded record.
3. Open the **Shop** tab to review entries under **To Buy** and **Purchased**.
4. Tap the circle beside an entry to mark it purchased; tap its checkmark to move it back to **To Buy**.
5. Swipe an entry to delete it.

Because each entry is a snapshot, it remains available even if the source inventory item or history record is later removed.

---

## iCloud / CloudKit Setup

1. **Sign in to your Apple Developer account** in Xcode → Preferences → Accounts.
2. In the **Signing & Capabilities** tab for the FridgePal target:
   - Set your **Team**.
   - Set **Bundle Identifier** to `com.fridgepal.app` (or your own unique ID).
   - Click **+ Capability** → add **iCloud**.
   - Under iCloud, enable **CloudKit** and add container `iCloud.com.fridgepal.app`.
   - Click **+ Capability** → add **Push Notifications** (required for CloudKit sync triggers).
3. The `PersistenceController` uses `.private("iCloud.com.fridgepal.app")` which creates a **private CloudKit database** — data is never shared with other users.
4. Sync uses `updatedAt` field to resolve conflicts (last-write wins).
5. **Offline support**: SwiftData writes locally first; CloudKit syncs automatically when connectivity returns.

---

## Building & Running

### Requirements
- Xcode 15+
- iOS 17+ device or simulator
- Apple Developer account (free or paid) for CloudKit

### Steps
1. Open `FridgePal/FridgePal.xcodeproj` in Xcode.
2. Set your Development Team in Signing & Capabilities.
3. Configure iCloud container as described above.
4. Select an iOS 17+ simulator or device.
5. Press **⌘R** to build and run.

### Running Tests
Press **⌘U** or Product → Test.

Tests cover:
- `ExpirationStateTests` — fresh / expiring-soon / expired / no-date logic
- `HomeAttentionItemsTests` — urgent grouping, priority order, and all-clear behavior
- `FoodItemStatusTests` — status enum roundtrips, graceful unknown values
- `ImageServiceTests` — resize/compress behavior
- `NotificationServiceTests` — schedule/cancel without crash
- `HistoryRecordTests` — archive creation from FoodItem
- `FoodFormDraftTests` — repeat-entry prefill, source independence, and new active-item creation
- `ShoppingItemTests` — inventory/history snapshots and reversible completion
- `ShoppingRepositoryTests` — persisted add, complete, reopen, and delete workflow

---

## Privacy Permissions (Info.plist)

| Key | Purpose |
|---|---|
| `NSCameraUsageDescription` | Taking food photos |
| `NSPhotoLibraryUsageDescription` | Selecting food photos from library |
| `NSPhotoLibraryAddUsageDescription` | Saving photos (if used) |

---

## Architecture

```
View  ←→  ViewModel  ←→  Repository  ←→  ModelContext (SwiftData)
                  ↕                              ↕
            Service Layer               CloudKit (automatic)
         (Notifications, CloudKit status, Image compression)
```

- **MVVM** — Views observe ObservableObjects / use `@Environment(\.modelContext)`.
- **Repository pattern** — `FoodRepository` wraps all SwiftData CRUD operations.
- **Service layer** — `NotificationService`, `CloudKitService`, `ImageService` are stateless/singleton helpers.
- **Offline-first** — All writes go to local SwiftData store first; CloudKit syncs in background.
