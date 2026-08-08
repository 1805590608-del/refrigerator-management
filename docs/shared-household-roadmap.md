# Shared Household / Collaboration Roadmap

**Status:** Roadmap — design only, no implementation in this document
**Priority:** P3 — strategic differentiator, not MVP work
**Suggested owner level:** Principal SDE

> This document is the parent plan for shared-household support in FridgePal. It captures the
> product decisions, architecture implications, migration risks, and a phased delivery plan.
> Individual implementation tasks should be filed as children of this roadmap.

---

## 1. Problem

FridgePal today persists everything through a **CloudKit private database**:

```swift
// FridgePal/FridgePal/Models/PersistenceController.swift
configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .private("iCloud.com.fridgepal.app")
)
```

That means every `FoodItem`, `HistoryRecord`, and `ShoppingItem` lives in exactly one Apple ID's
private zone. It syncs across that user's own devices and cannot be seen or edited by anyone else.

Real household food management is collaborative: a partner buys the milk, a roommate finishes the
leftovers, a parent adds "eggs" to the shopping list. Because there is no notion of a household,
the app cannot support:

- shared inventory ownership (whose fridge is this?),
- shared actions (who marked the yoghurt as eaten?),
- shared shopping lists (two people buying the same tomatoes),
- shared history and waste insights (household-level waste ratio).

## 2. User story

> As a household using FridgePal together, we want to share the same fridge inventory so everyone
> can see updates and act on them.

Supporting stories:

- As a household owner, I want to invite my partner/roommate so they can see and edit our fridge.
- As a member, I want to know who added or removed an item so we can hold each other accountable.
- As a member, I want to keep a personal space separate from the shared household.
- As an owner, I want to remove a member who has moved out and keep the household data.

## 3. Scope

**In scope for this roadmap**

- Roadmap-level design and implementation plan for collaborative inventory.
- Evaluation of data-model and CloudKit implications of moving beyond private single-user storage.
- UX requirements: invite/join household, shared fridge context, edit semantics, accountability.
- Phased delivery with risks and prerequisites.

**Out of scope**

- The full shared-household implementation.
- Real-time collaboration guarantees (live cursors, sub-second propagation, presence).
- Cross-platform (non-Apple) accounts or a custom backend.

## 4. Product decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Sharing unit | **Household** (a named container that owns fridges/inventory), not per-item sharing | Per-item sharing produces an unmanageable invite surface and confusing history |
| D2 | Personal vs household | Both. A user always has a **Personal** space; households are additional spaces the user can switch between | Preserves today's single-user behavior and gives a safe destination for opt-out data |
| D3 | Membership model | Roles: **Owner**, **Member**. (A read-only **Viewer** role is deferred) | Two roles cover the household use case; more roles add permission UI cost with little benefit |
| D4 | Edit semantics | **Last-write-wins per field**, driven by the existing `updatedAt` timestamp | Matches the current documented conflict policy; full CRDT/OT is unjustified for this domain |
| D5 | Delete semantics | Destructive actions (delete, bulk delete, clear history) require confirmation and are attributed | Bulk actions already exist and are the highest-blast-radius operation in a shared context |
| D6 | Accountability | Attribution metadata on items plus a household **Activity feed** | "Who ate it?" is the single most requested collaboration affordance |
| D7 | Identity | Apple ID / iCloud identity via CloudKit sharing; no separate account system | Zero-backend, aligns with current architecture and privacy posture |
| D8 | Offline behavior | Offline-first is preserved; queued local writes replay on reconnect | Non-negotiable — it is the app's existing guarantee |
| D9 | Notifications | Reminders stay **local and per-device**, computed from the currently active space | Avoids server-side fan-out; keeps `ReminderPlanner` unchanged in shape |
| D10 | Data on leaving | Leaving a household removes local access; it does **not** delete household data | Prevents accidental destruction of a shared inventory |

### Open questions

- **Q1** Should history follow the item into a household, or stay with the user who archived it?
  *Leaning:* history belongs to the household; personal history stays personal.
- **Q2** Should shopping lists be shareable independently of inventory (a "shopping only" household)?
  *Leaning:* no in Phase 1–3; revisit after adoption data.
- **Q3** Do we support a user belonging to multiple households (e.g. home + parents' house)?
  *Leaning:* yes at the model level from day one, but the UI may launch with one household.
- **Q4** Photo storage cost in a shared zone — do we downscale further for shared items?
  `ImageService` already caps at 1600px / JPEG 0.75; measure before changing.

## 5. Architecture implications

### 5.1 CloudKit database topology

| Option | Description | Verdict |
|---|---|---|
| A. Private DB only (today) | One private zone per user | Cannot share — status quo |
| B. **Private DB + `CKShare` on a custom zone** | Household records live in a shared custom zone owned by the household creator; participants access it through the shared database | **Recommended** |
| C. Public DB | All records public with app-level ACLs | Rejected — privacy, quota, and abuse risk |
| D. Custom backend | Own server with auth and sync | Rejected — contradicts the zero-backend architecture |

Option B is the standard Apple mechanism (`CKShare` + `UICloudSharingController`) and is what
SwiftData exposes today. The critical constraint is that **`ModelConfiguration` selects a single
CloudKit database per configuration**. Supporting a personal space *and* a shared space therefore
requires either:

1. **Multiple `ModelConfiguration`s in one `ModelContainer`**, each mapped to a subset of the
   schema and a different `cloudKitDatabase` value, or
2. **Multiple `ModelContainer`s** — one per space — with the app swapping the container/context
   injected into the environment when the active space changes.

Approach (2) is the more predictable of the two because SwiftData's per-model-type routing is
awkward when the *same* type must exist in both a private and a shared store. It does mean
`PersistenceController.shared` can no longer be a single immutable container; it becomes a factory
plus an observable "active space" selector, and the app root re-injects `\.modelContext` on change.

**Prerequisite spike:** verify on the minimum supported OS that SwiftData can drive a `CKShare`
end to end (accept share → records materialize → writes propagate). If it cannot, the fallback is
a hand-rolled `CKSyncEngine`/`NSPersistentCloudKitContainer`-style layer behind the existing
repository protocols — which is precisely why the repository abstraction must be preserved.

### 5.2 Data model changes

New models:

```
Household        id, name, ownerParticipantID, createdAt, updatedAt
HouseholdMember  id, householdID, participantID, displayName, role, joinedAt
ActivityEvent    id, householdID, actorID, actorDisplayName, entityType,
                 entityID, entityName, action, occurredAt
```

Changes to existing models (all **additive and optional**, so old records remain valid):

| Model | Added fields | Purpose |
|---|---|---|
| `FoodItem` | `householdID: UUID?`, `createdByID: String?`, `createdByName: String?`, `updatedByID: String?`, `updatedByName: String?` | Space ownership + attribution |
| `HistoryRecord` | `householdID: UUID?`, `archivedByID: String?`, `archivedByName: String?` | "Who threw it out?" and household waste insights |
| `ShoppingItem` | `householdID: UUID?`, `createdByID: String?`, `completedByID: String?`, `completedByName: String?` | "Who bought it?" and duplicate-purchase avoidance |

Notes:

- `householdID == nil` means the record belongs to the user's personal space. This keeps every
  existing record valid with no data migration on upgrade.
- Attribution IDs should be the **CloudKit participant user record name**, not raw Apple ID data,
  and display names come from `CKShare.Participant` — do not persist emails or phone numbers.
- New fields must be optional (or have defaults) so CloudKit's lightweight-migration requirement
  — CloudKit-backed schemas cannot have required-without-default attributes — is satisfied.

### 5.3 Dependencies on current behavior

The following existing behaviors are directly coupled to this work and must be revisited:

- **`PersistenceController`** — currently a single immutable private-DB container; becomes
  space-aware (see 5.1). Its local-only fallback path must keep working when iCloud is unavailable.
- **`FoodRepository` / `ShoppingRepository`** — every fetch (`fetchAll`, `fetchActive`,
  `fetchHistory`) must be scoped to the active space; today they fetch unconditionally. This is the
  main correctness risk: an unscoped fetch leaks another space's items into the UI.
- **Bulk actions** (`archiveItems`, `deleteItems`) — highest blast radius in a shared household;
  need attribution, activity events, and (Phase 4) undo.
- **Shopping list** (`ShoppingItem` is an independent snapshot, not a relationship) — this design
  is *helpful* here: snapshots avoid cross-space relationship graphs. Duplicate-purchase detection
  becomes a new requirement ("Alex already marked this purchased").
- **History and waste insights** — aggregations become household-level; the UI needs a
  household/personal scope toggle so a member's personal stats are not silently merged.
- **`ReminderPlanner` / `NotificationService`** — reminders are scheduled from local items; they
  must be rescheduled whenever the active space changes or a shared sync lands, and must not
  double-notify a household member for an item another member already resolved.
- **`CloudKitService`** — currently reports account status only; extends to share acceptance state,
  participant list, and per-space sync status.
- **Settings (`@AppStorage`)** — reminder/appearance preferences stay per-user, per-device. Only
  household-level settings (name, member list) sync.

## 6. UX requirements

### 6.1 Invite / join household

- Settings → **Household** → *Create household* (name it) or *Join household*.
- Owner shares via the system share sheet (`UICloudSharingController`) — Messages, Mail, link.
- Invitees accept via the link; the app handles the incoming share and shows a confirmation screen
  naming the household and its owner before any data is merged.
- Owner can view members, remove a member, and stop sharing entirely.
- Error states: iCloud signed out, invite expired/revoked, storage quota exceeded, network offline.

### 6.2 Shared fridge context

- A persistent, always-visible **space switcher** (Personal ↔ household name) in the navigation
  bar or Settings header. Ambiguity about "which fridge am I editing?" is the top usability risk.
- The active space is remembered per device and is reflected in Home, List, Shopping, and History.
- Empty and loading states must name the space explicitly ("No items in *Flat 3B*").

### 6.3 Edit semantics

- Any member can add, edit, archive, and delete items (D3); only the Owner can rename the
  household, remove members, or delete the household.
- Concurrent edits resolve last-write-wins on `updatedAt`; the UI should surface a non-blocking
  "Updated by Sam just now" hint rather than a conflict dialog.
- Destructive and bulk actions keep their existing confirmation, extended with scope wording
  ("Delete 6 items from *Flat 3B* for everyone?").
- Quantity adjustments (±1) are the most collision-prone edit; consider delta-based application
  before overwriting the absolute value.

### 6.4 Accountability / activity visibility

- Item detail shows "Added by Alex · Updated by Sam".
- History shows "Discarded by Sam".
- A household **Activity** view lists recent events (added / edited / archived / purchased /
  deleted) with actor, item, and timestamp. Retention capped (e.g. 90 days or 500 events) to
  bound storage.
- Attribution is informational, not punitive — copy should avoid blame framing.

### 6.5 Accessibility & localization

- All new strings go through `NSLocalizedString` with `en` and `zh-Hans` entries, matching the
  existing `Resources/*.lproj/Localizable.strings` convention.
- Space switcher, invite flow, and activity rows need VoiceOver labels and Dynamic Type support.

## 7. Phased delivery

| Phase | Goal | Key work | Exit criteria |
|---|---|---|---|
| **0. Spike** | De-risk the platform | Prove SwiftData + `CKShare` end-to-end on a throwaway branch; measure sync latency and photo quota impact | Written go/no-go with a chosen topology (5.1) |
| **1. Space foundation** | Make the app space-aware *without* sharing | Add `householdID` (nullable) to all three models; scope every repository fetch; introduce the active-space selector with only "Personal" available | No behavior change for existing users; regression tests green |
| **2. Household + invites** | Two users, one inventory | `Household`/`HouseholdMember` models, create/invite/join/leave flows, share acceptance, space switcher UI | Two devices with different Apple IDs see the same inventory and can edit it |
| **3. Attribution & activity** | Answer "who did that?" | Attribution fields, `ActivityEvent`, activity feed, attributed history | Every mutating action is attributed and visible to members |
| **4. Collaboration polish** | Make it pleasant | Household-scoped waste insights, duplicate-purchase hints on the shopping list, delta-based quantity edits, undo for bulk actions, per-space reminder rescheduling | Collaboration usability review passes |
| **5. Advanced (optional)** | Stretch | Viewer role, multiple households in UI, per-member notification preferences, household onboarding | Driven by adoption data |

Phases 1 and 2 are the only hard sequencing constraint; 3–5 can be reordered by product priority.

### Prerequisites

- Phase 0 spike outcome (blocks everything).
- Paid Apple Developer account and a CloudKit container configured for sharing; the existing
  `iCloud.com.fridgepal.app` container plus the Push Notifications capability already documented in
  the README are a prerequisite for share change notifications.
- A two-device / two-Apple-ID manual test setup, since sharing cannot be exercised in a single
  simulator.
- Repository-level test coverage for scoping before any store topology change (Phase 1).

## 8. Risks

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| SwiftData's `CKShare` support is insufficient or buggy on supported OS versions | High | Medium | Phase 0 spike; keep repository protocols so a CloudKit-native fallback can be swapped in |
| **Data loss during migration** between private and shared stores | Critical | Medium | Never move records as the first step — copy, verify, then delete; back up locally before migration; make migration explicitly user-initiated and resumable |
| Unscoped fetch leaks items across spaces | High | Medium | Scope in the repository layer only (single choke point) and cover with tests in Phase 1 |
| Silent conflict loss from last-write-wins | Medium | High | Field-level `updatedAt`, delta-based quantity edits, visible "updated by" hints |
| Bulk delete by one member destroys shared data | High | Medium | Scoped confirmation copy, attribution, undo window (Phase 4) |
| CloudKit quota/perf regressions from shared photos | Medium | Medium | Measure in Phase 0; keep `.externalStorage`; consider thumbnails for shared items |
| Privacy: participant identity or personal-space data leaking into a household | High | Low | Store only participant record IDs and display names; personal space never syncs into a shared zone |
| Notification duplication/noise across members | Medium | High | Keep reminders local and per-space; reschedule on sync and on space change |
| Scope creep into real-time collaboration | Medium | High | Explicitly out of scope; revisit only after Phase 4 |
| Social/abuse risk (a removed member retaining access) | Medium | Low | Owner-driven removal revokes the `CKShare` participant; verify local cache purge on revoke |

## 9. Success metrics

- % of active users who create or join a household.
- Median household size and 30-day household retention vs single-user retention.
- Reduction in household waste ratio (existing waste-insights metric) after joining.
- Conflict/overwrite incidents per 1,000 shared edits (should trend to ~0).
- Crash-free rate and sync-error rate for shared spaces vs personal spaces.

## 10. Follow-up implementation tasks

This roadmap is intended to act as a parent issue. Suggested children:

1. Phase 0 spike: SwiftData + `CKShare` feasibility report.
2. Add nullable `householdID` to `FoodItem`, `HistoryRecord`, `ShoppingItem` (+ migration test).
3. Scope `FoodRepository` and `ShoppingRepository` fetches to the active space.
4. Introduce space-aware `PersistenceController` and active-space selector.
5. `Household` and `HouseholdMember` models plus household management service.
6. Invite / join / leave flows and share acceptance handling.
7. Space switcher UI and space-aware empty/loading states.
8. Attribution fields and item/history attribution UI.
9. `ActivityEvent` model and household activity feed.
10. Household-scoped waste insights and shopping-list duplicate-purchase hints.
11. Per-space reminder rescheduling.
12. Localization (`en`, `zh-Hans`) and accessibility pass for all new surfaces.
