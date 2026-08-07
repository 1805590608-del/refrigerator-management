# FridgePal — Refrigerator Food Management iOS App

A full-featured iOS app for tracking household food inventory, expiration dates, and consumption. Built with SwiftUI + SwiftData + CloudKit.

---

## Features

| Feature | Details |
|---|---|
| **Home Dashboard** | Total count, expiring-soon count, expired count, recent items, location breakdown |
| **Food List** | List/grid toggle, search, filter by status/category/location, sort by date/name |
| **Add / Edit Food** | Camera or photo library, name, category, location, quantity, unit, purchase/expiry dates, notes |
| **Quick Add** | Add an active item again from inventory details or history with every field prefilled and editable |
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
    │   └── PersistenceController.swift  # ModelContainer + CloudKit setup
    ├── Repositories/
    │   └── FoodRepository.swift    # CRUD + archive operations
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
- `FoodItemStatusTests` — status enum roundtrips, graceful unknown values
- `ImageServiceTests` — resize/compress behavior
- `NotificationServiceTests` — schedule/cancel without crash
- `HistoryRecordTests` — archive creation from FoodItem
- `FoodFormDraftTests` — repeat-entry prefill, source independence, and new active-item creation

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
