# FridgePal — Refrigerator Food Management iOS App

A full-featured iOS app for tracking household food inventory, expiration dates, and consumption. Built with SwiftUI + SwiftData + CloudKit.

---

## Features

| Feature | Details |
|---|---|
| **Home Dashboard** | Prioritized “Expired Now” and “Use Soon” actions with direct item drill-down, plus summary counts, recent items, and location breakdown |
| **Food List** | List/grid toggle, search, filter by status/category/location, sort by date/name |
| **Bulk Actions** | Multi-select foods in the list to mark them all gone/discarded, add them to the shopping list, or delete them, with confirmation before destructive batches |
| **Add / Edit Food** | Camera or photo library, name, category, location, quantity, unit, purchase/expiry dates, notes |
| **Quick Add** | Add an active item again from inventory details or history with every field prefilled and editable |
| **Shopping List** | Save active or archived foods to buy again; mark entries purchased, move them back to “To Buy,” or remove them |
| **Food Detail** | Full info view, quantity ±1 adjuster, mark eaten/discarded, delete with confirmation |
| **Expiration Reminders** | Local notifications 1/3/7 days before expiry, grouped into one daily summary at a time you pick, with urgent wording for food expiring today or tomorrow |
| **iCloud Sync** | SwiftData + CloudKit private database; offline-first, auto-sync on reconnect |
| **History** | Eaten/discarded/expired archive; statistics and waste insights by time range (waste ratio, most-wasted category, most-wasted location); bulk clear |
| **Settings** | Reminder days, daily-summary toggle, reminder time, iCloud status check, list/grid preference, appearance |
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
    │   ├── FoodRepository.swift    # Inventory CRUD + single/batch archive & delete
    │   └── ShoppingRepository.swift # Shopping-list persistence
    ├── Services/
    │   ├── NotificationService.swift   # Local notification scheduling
    │   ├── ReminderPlanner.swift       # Reminder settings + grouped reminder planning
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
    │   ├── FoodListView.swift      # List + grid + swipe actions + multi-select bulk actions
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

### Bulk Actions Workflow

1. In the **My Fridge** tab, tap the checklist button in the navigation bar to enter selection mode.
2. Tap rows to select them, or use **Select All** / **Deselect All** in the bottom bar. The bottom bar shows how many foods are selected.
3. Open **Bulk Actions** and choose one of:
   - **Mark as All Gone** / **Mark as Discarded** — archives every selected food to History.
   - **Add to Shopping List** — creates a buy-again snapshot for each selected food and keeps the foods in the fridge.
   - **Delete** — permanently removes the selected foods.
4. Destructive batches ask for confirmation first; **Cancel** or **Done** leaves selection mode.

Selection applies only to the foods currently visible under the active search and filters, so filtering first is the fastest way to clean out, for example, every expired item.

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

Sharing one fridge between several people is not supported yet — see the
[Shared Household / Collaboration Roadmap](docs/shared-household-roadmap.md) for the planned design.

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
- `ReminderSettingsTests` — reminder preference parsing, normalization, and defaults
- `ReminderPlannerTests` — daily digest grouping, urgency, ordering, and pending-notification limit
- `HistoryRecordTests` — archive creation from FoodItem
- `WasteInsightsTests` — waste ratio, most-wasted category, and most-wasted location aggregations
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
