# Barcode + OCR Capture — Discovery Spike

**Status:** Spike findings and recommendation — design only, no implementation in this document
**Priority:** P3 — friction reducer, scheduled after MVP improvements
**Suggested owner level:** Principal SDE

> This document records the discovery spike for barcode- and OCR-assisted grocery capture in
> FridgePal. It answers the go/no-go question, names the recommended architecture and user flow,
> and lists privacy implications, effort, and risks. Implementation work should be filed as
> children of this spike.

---

## 1. Problem

Adding an item today is entirely manual. `AddEditFoodView` collects name, category, storage
location, quantity, unit, purchase date, expiration date, notes and an optional photo, and every
one of those fields is typed or picked by hand:

```swift
// FridgePal/FridgePal/ViewModels/AddEditFoodViewModel.swift
struct FoodFormDraft {
    var name: String
    var category: FoodCategory
    var storageLocation: StorageLocation
    var quantity: Double
    var unit: String
    var purchaseDate: Date
    var expirationDate: Date
    var hasExpirationDate: Bool
    var photoData: Data?
    var notes: String
}
```

A weekly shop of 15 items is therefore 15 form passes. Quick Add already reduces the cost of
*repeat* entries by prefilling a draft from an existing `FoodItem` or `HistoryRecord`, but it does
nothing for items the user has never logged. Capture-assisted entry is the natural complement:
**Quick Add covers items you have had before, scanning covers items you have not.**

## 2. User story

> As a FridgePal user, I want the app to recognize food information from packaging or labels so I
> can log groceries faster.

Supporting stories:

- As a user scanning a packaged item, I want its name and category filled in for me.
- As a user photographing a "best before" date, I want the expiration date filled in for me.
- As a user, I want to see and correct anything the app guessed before it is saved.
- As a privacy-conscious user, I want to know whether my camera images leave the device.

## 3. Scope of the spike

**In scope**

- iOS-native capabilities for barcode scanning and on-device text recognition.
- Candidate flows for packaged items (barcode), date extraction (OCR), and the human-review step.
- Expected accuracy, limits, privacy implications, and UX tradeoffs.
- A recommendation with architecture fit, effort, and risks.

**Out of scope**

- Production rollout of barcode/OCR capture.
- Paid third-party recognition services.
- General food recognition from an unpackaged photo (classifying a loose tomato).
- Receipt scanning (a separate, larger problem — see §10).

## 4. Findings

### 4.1 Barcode scanning is a solved platform problem

`VisionKit`'s `DataScannerViewController` provides a ready-made, accessible, live camera scanner
that recognizes barcodes and text in one pass. Vision's `VNDetectBarcodesRequest` is the lower
level alternative for scanning a still image or a custom `AVCaptureSession`.

| Aspect | Finding |
|---|---|
| Symbologies | EAN-13/EAN-8, UPC-A/UPC-E, Code 128, QR and more — covers all retail grocery packaging |
| Availability | `DataScannerViewController` requires iOS 16+ and a device with the Neural Engine (A12+); the app already targets iOS 17+ |
| Simulator | **Not supported** — `DataScannerViewController.isSupported` is `false`; all validation needs a physical device |
| Accuracy | Effectively 100% for a legible, in-focus barcode. Barcodes are checksummed, so a misread is a *non-read*, not a wrong read |
| Cost | Free, on-device, no network |

**The scanner is not the hard part. The barcode-to-food lookup is.**

A barcode is only a number (GTIN). Turning `5000112552126` into "Coca-Cola 500ml, Drinks" requires a
product database, and Apple provides none.

| Option | Verdict |
|---|---|
| A. **Local catalog built from the user's own history** — remember the barcode the user attached to an item and prefill from it next time | **Recommended for Phase 1.** Zero network, zero cost, no privacy exposure, and improves with use |
| B. Open Food Facts (free, open, crowd-sourced, ~3M products) | **Recommended for Phase 2**, opt-in. Good coverage in EU, thinner in some regions; data quality is uneven; sends the barcode (not the image) to a third party |
| C. Commercial GTIN APIs | Rejected for now — recurring cost and a vendor dependency that the spike does not justify |
| D. Bundled offline catalog | Rejected — app size and staleness |

Option A means the first scan of a new product still requires typing, but the *second* scan of that
product — the common case for household staples — is instant. This is the same insight Quick Add is
built on, keyed by barcode instead of by item identity.

### 4.2 OCR for dates works, with caveats

`VNRecognizeTextRequest` (Vision) performs on-device text recognition with no network access and no
per-use cost.

| Aspect | Finding |
|---|---|
| Recognition level | `.accurate` is required; `.fast` misses small printed dates |
| Languages | `en` and `zh-Hans` are both supported; set `recognitionLanguages` to match the app's localizations |
| Custom words | `customWords` can bias toward "BEST BEFORE", "EXP", "USE BY", "保质期", "此日期前食用" |
| Latency | Sub-second on a single still frame on modern hardware; live recognition is feasible but not needed |
| Cost | Free, on-device, no network |

The failure modes are physical, not algorithmic. Date codes on packaging are frequently
low-contrast ink-jet or laser-etched characters on curved, glossy, or crumpled surfaces, printed in
a condensed font. Realistic expectations from the spike:

- **Text detection** on flat, high-contrast labels: reliable.
- **Text detection** on embossed/etched codes on plastic or foil: unreliable; recognition frequently
  returns nothing or a partial string.
- **Date parsing** is a second, independent source of error. Formats vary wildly
  (`12/03/25`, `2025-03-12`, `12 MAR 25`, `MAR1225`, `L25071 12/03/25`), and `12/03/25` is
  genuinely ambiguous between locales.
- Packaging often contains **several** dates (manufacture date, batch code, print date), so the
  right one has to be chosen, not just found.

**Consequence:** OCR must be treated as a *suggestion engine*, never as an authority. A silently
wrong expiration date is worse than no date at all, because it drives the notification and waste
logic (`ReminderPlanner`, `ExpirationState`) and would cause either false alarms or food eaten past
its date.

### 4.3 Ambiguity resolution rules (proposed)

If a date suggestion is surfaced, it must come with deterministic rules:

- Parse candidates with an explicit allow-list of formats plus a keyword-proximity boost for
  "best before" / "use by" / "exp" / "保质期".
- Reject any candidate in the past or more than ~5 years out.
- Prefer, among remaining candidates, the **latest** date (manufacture/batch dates are earlier).
- For a `dd/mm` vs `mm/dd` ambiguity, resolve using the device locale, and always show the resolved
  date as a formatted, human-readable string ("12 March 2025") so a mis-resolution is obvious.
- If more than one plausible candidate survives, present them as choices rather than picking one.

### 4.4 Human review is mandatory, not optional

Both flows must land in the existing `AddEditFoodView` form with fields **prefilled and editable**,
exactly as Quick Add does today. Nothing recognized should ever be written straight to the store.
Recognized fields should be visually marked as suggestions (for example a "Scanned" chip that
disappears once the user edits the field) so the user knows what to double-check.

This is the single most important UX finding: the review step is what makes an imperfect recognizer
acceptable.

## 5. Recommendation

**Go — build it, in phases, on-device only, behind a repository/service abstraction, with barcode
before OCR.**

Rationale:

1. Both capabilities are free, native, on-device, and align with FridgePal's zero-backend, private
   architecture. No new runtime dependency and no new privacy surface beyond the camera permission
   the app already requests.
2. The integration point already exists. `FoodFormDraft` is the app's established "prefilled,
   user-confirmed draft" abstraction (built for Quick Add); scanning is another producer of a
   draft. No model or persistence change is required for Phase 1 beyond an optional barcode field.
3. The risk is contained by the review step. The worst realistic outcome is a wrong suggestion the
   user corrects — the same cost as today's manual entry.

Sequencing barcode first is deliberate: it is the higher-confidence, lower-ambiguity half, and it
lets the local barcode catalog accumulate before any date OCR is added.

### 5.1 Architecture fit

New code should be additive and isolated:

```
Services/
  BarcodeScanner.swift     // VisionKit/Vision wrapper -> String (GTIN) + symbology
  TextRecognizer.swift     // Vision wrapper -> [recognized strings] from image data
  ExpirationDateParser.swift  // pure, testable: [String] -> [Date candidates]
  ProductLookup.swift      // protocol; local-history implementation in Phase 1
Models/
  FoodItem.barcode: String?   // optional, additive, CloudKit-safe
Views/
  ScanSheet.swift          // presented from Add/Edit and (later) the list toolbar
```

Design constraints:

- `ExpirationDateParser` must be a **pure value type with no Vision dependency** so it is unit
  testable in `FridgePalTests` on a simulator, the way `ReminderPlanner`, `WasteInsights`, and
  `FoodFormDraft` already are. Camera and Vision code cannot be tested in CI; the parsing logic is
  where the real defects live, so it must be separable.
- `ProductLookup` must be a protocol so the local-history implementation can be swapped for (or
  chained with) a network implementation later without touching the UI.
- Every scan path terminates in a `FoodFormDraft`, never in a direct repository write.
- The new `barcode` field must be **optional** so CloudKit's lightweight-migration requirement is
  satisfied and existing records stay valid.

### 5.2 User flow

**Packaged item via barcode**

1. Add (`+`) → **Scan** → live scanner sheet.
2. Barcode read → look up in local catalog (Phase 2: then the opt-in remote source).
3. Hit → Add/Edit form opens prefilled (name, category, unit, typical quantity) with the source
   shown; miss → form opens with only the barcode attached and a note that the next scan of this
   product will remember it.
4. User reviews, adjusts, saves. The barcode is persisted with the item, teaching the catalog.

**Date from a label via OCR**

1. Inside Add/Edit, next to the expiration date field → **Scan date**.
2. Single still capture (not continuous) → on-device text recognition → candidate dates.
3. Zero candidates → "Couldn't read a date — enter it manually", form unchanged.
   One candidate → date field prefilled and flagged as scanned.
   Several candidates → a short picker listing formatted dates.
4. User confirms or edits, then saves.

**Design rules**

- Scanning is always an *optional accelerator*; every manual path stays exactly as it is today.
- The scanner sheet needs a visible manual-entry escape hatch and a torch toggle (date codes are
  usually poorly lit).
- Recognition failure is a neutral, non-blocking message — never an error dialog.
- All new strings go through `NSLocalizedString` with `en` and `zh-Hans` entries, matching
  `Resources/*.lproj/Localizable.strings`. The scanner needs VoiceOver labels and a
  non-camera fallback, since a live camera viewfinder is not usable by every user.

### 5.3 Privacy

- **Everything in Phase 1 stays on device.** Vision and VisionKit perform no network requests, and
  no image is uploaded anywhere.
- Camera access is already declared (`NSCameraUsageDescription` in `Info.plist`). The string should
  be broadened to mention scanning barcodes and labels, because the current wording only promises
  photos of food items and the purpose must match the actual use.
- Frames used for recognition are transient: recognize, extract, discard. Only the user's chosen
  photo goes through `ImageService` and into `photoData` as it does today. No OCR frame or raw
  recognized text should be persisted, and none should be logged.
- A barcode is a product identifier, not personal data, but the **set** of barcodes a household
  scans is a shopping profile. Therefore any remote lookup (Phase 2) must be:
  opt-in, disclosed in Settings, barcode-only (never an image), unauthenticated, without any device
  or user identifier, and fully functional when declined.
- The local barcode catalog is user data and syncs through the existing private CloudKit database —
  no new sharing surface.

### 5.4 Effort

| Phase | Work | Estimate |
|---|---|---|
| **1a. Barcode capture** | `BarcodeScanner`, scanner sheet, optional `FoodItem.barcode`, local catalog lookup keyed on barcode, prefill into `FoodFormDraft`, localization + accessibility | ~1.5–2 weeks |
| **1b. Date OCR** | `TextRecognizer`, `ExpirationDateParser` + unit tests, candidate picker, "scanned" field affordance | ~1.5–2 weeks |
| **2. Remote product lookup (opt-in)** | `ProductLookup` network implementation, Settings toggle + disclosure, caching, offline/failure handling | ~1–1.5 weeks |
| **3. Polish** | Batch scanning (scan several items in one session), scan entry point from the list toolbar, accuracy telemetry | ~1 week |

Excludes device-matrix QA. Phase 1a and 1b are independently shippable; Phase 2 is optional and
should be gated on Phase 1 adoption data.

### 5.5 Risks

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| OCR misreads a date and the wrong expiry drives reminders/waste stats | High | High | Mandatory review step; never auto-save; sanity bounds (§4.3); mark scanned fields |
| Barcode scans with no product data feel broken ("it scanned and did nothing") | Medium | High | Explicit copy that the first scan teaches the app; local catalog first; opt-in remote lookup later |
| Cannot be tested in the simulator or in CI | Medium | Certain | Keep Vision at the edges; unit test the pure parser and lookup logic; document a manual device test plan with real packaging |
| Regional/format variance in date codes | Medium | High | Locale-aware parsing, explicit format allow-list, multi-candidate picker instead of guessing |
| Scope creep into full food recognition or receipt scanning | Medium | Medium | Explicitly out of scope (§3); revisit only after Phase 1 adoption data |
| Third-party catalog coverage or licensing surprises in Phase 2 | Medium | Medium | Opt-in only, app fully functional without it, verify licence and attribution before shipping |
| Camera permission denial or older/unsupported hardware | Low | Medium | Feature-detect (`DataScannerViewController.isSupported`/`isAvailable`); hide the entry point and keep manual entry unchanged |
| Accessibility regression (camera-only affordance) | Medium | Low | Scanning never replaces a manual path; VoiceOver labels and audible scan confirmation |

### 5.6 Prototype status

**No prototype code is included in this change.** The spike is documentation-only by design: the
capabilities that would need proving (`DataScannerViewController`, `VNRecognizeTextRequest`) cannot
run in the simulator or in CI, so a prototype could not be validated here, and shipping unverified
camera code into the app target would risk degrading production capture UX for no confirmed
benefit. When a prototype is built, it must be scoped as experimental behind a development-only
entry point, must not alter any existing Add/Edit path, and must terminate in a `FoodFormDraft` for
review rather than writing to the store.

## 6. Success metrics

- % of new items created via a scan-assisted path.
- Median time to add a new (non-repeat) item, scan-assisted vs manual.
- Barcode local-catalog hit rate after 30 days of use.
- Share of OCR date suggestions accepted without edit (accuracy proxy) and share of scans that
  produce no candidate (coverage proxy).
- No regression in add-flow abandonment or crash-free rate.

## 7. Follow-up implementation tasks

This spike is intended to act as a parent issue. Suggested children:

1. Add optional `barcode` field to `FoodItem` (additive, CloudKit-safe) plus a migration test.
2. `BarcodeScanner` service and scanner sheet with feature detection and permission handling.
3. Local barcode → product catalog lookup built from the user's own history, behind `ProductLookup`.
4. Barcode-driven `FoodFormDraft` prefill and "scanned" field affordance in Add/Edit.
5. `TextRecognizer` service (on-device, `en` + `zh-Hans`).
6. `ExpirationDateParser` pure parser with unit tests covering multi-format and ambiguous input.
7. Date-candidate picker UI and expiration-field integration.
8. Broaden `NSCameraUsageDescription` and document the on-device privacy posture.
9. Localization (`en`, `zh-Hans`) and accessibility pass for all scanning surfaces.
10. Manual device test plan across real packaging (glossy, curved, etched, low-contrast).
11. *(Optional, gated)* Opt-in remote product lookup with Settings disclosure and caching.
