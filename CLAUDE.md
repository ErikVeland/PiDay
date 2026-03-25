# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PiDay is an iOS SwiftUI app that lets users search for their birthdate (or any date) within the digits of Pi. It shows a calendar heat map indicating how early each date appears in Pi's decimal expansion.

## Build & Test Commands

The project uses XcodeGen (`project.yml`) to generate the Xcode project.

```bash
# Regenerate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -scheme PiDay -configuration Debug build

# Run all tests
xcodebuild -scheme PiDay -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test method
xcodebuild -scheme PiDay -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PiDayTests/PiDayCoreTests/testMethodName
```

## Architecture

MVVM with SwiftUI, using `@Observable` (Swift 5.9 / iOS 17) throughout. `ObservableObject` / `@Published` are no longer used.

### Source layout

```
PiDay/
├── PiDayApp.swift                  — app entry point; injects AppViewModel and PreferencesStore as @Environment
│
├── Core/
│   ├── Data/
│   │   ├── DateStringGenerator.swift   — pure function: Date → [(DateFormatOption, queryString)]
│   │   └── PiIndexPayload.swift        — Codable types for the bundled JSON index
│   ├── Domain/
│   │   ├── AppTheme.swift              — theme enum + ThemePalette color tokens
│   │   ├── CalendarModels.swift        — CalendarDay, MonthSection, DaySummary
│   │   ├── DateFormatOption.swift      — YYYYMMDD / DDMMYYYY / MMDDYYYY / YYMMDD / D/M/YYYY
│   │   ├── IndexingConvention.swift    — 0-based vs 1-based display offset
│   │   ├── PiMatch.swift               — PiMatchResult, BestPiMatch, DateLookupSummary, ShareableCard
│   │   ├── SavedDate.swift             — Codable SavedDate model
│   │   └── SearchFormatPreference.swift — International / American / ISO 8601 / All
│   └── Repository/
│       ├── PiRepository.swift          — @MainActor protocol; the only interface AppViewModel uses
│       ├── DefaultPiRepository.swift   — concrete impl: routes to bundled index or live API
│       ├── PiStore.swift               — loads + queries pi_2026_2035_index.json
│       └── PiLiveLookupService.swift   — hits pisearch API for out-of-range dates; parallel fan-out per format
│
├── Design/
│   ├── PiPalette.swift                 — semantic color tokens (day=orange, month=teal, year=blue, heat levels)
│   └── ViewModifiers.swift             — NativeGlassButtonModifier, CompactSectionCardModifier
│
├── Features/
│   ├── Main/
│   │   ├── AppViewModel.swift          — @MainActor @Observable; owns all search state, navigation, caching
│   │   └── MainView.swift              — root layout: canvas + wordmark + bottom controls + sheet presentation
│   ├── Canvas/
│   │   └── PiCanvasView.swift          — Pi digit canvas with highlighted date sequence and reveal animation
│   ├── Calendar/
│   │   └── CalendarSheetView.swift     — calendar heat map sheet
│   ├── Detail/
│   │   └── DetailSheetView.swift       — detail/settings sheet
│   ├── FreeSearch/
│   │   ├── FreeSearchView.swift
│   │   └── FreeSearchViewModel.swift   — arbitrary digit-sequence search via PiLiveLookupService
│   ├── Preferences/
│   │   ├── PreferencesView.swift
│   │   └── PreferencesComponents.swift
│   ├── SavedDates/
│   │   └── SavedDatesView.swift
│   └── Share/
│       └── ShareCardView.swift         — rendered share card (ImageRenderer → PNG via ShareLink)
│
├── Services/
│   ├── PreferencesStore.swift          — @Observable appearance prefs (theme, fontStyle, digitSize, customAccent)
│   ├── SavedDatesStore.swift           — @Observable saved-dates list; persisted via Codable + UserDefaults
│   └── NotificationService.swift       — static enum; schedules annual Pi Day reminder (Mar 14 @ 9:14 AM)
│
└── Resources/
    └── pi_2026_2035_index.json         — bundled exact-match index, years 2026–2035
```

### Key types

- **`AppViewModel`** — `@MainActor @Observable`. Owns `selectedDate`, `displayedMonth`, `lookupSummary`, `isLoading`, `searchPreference`, `indexingConvention`, `daySummaries`, `savedDatesStore`, and `shouldPromptForRating`. `SearchState` struct no longer exists — those properties are inlined directly. Accepts a `PiRepository` parameter for test injection; defaults to `DefaultPiRepository`.
- **`PiRepository`** — `@MainActor` protocol. The only interface `AppViewModel` uses. Hides whether a lookup comes from the bundled index or the live API.
- **`DefaultPiRepository`** — Concrete impl. Routes by year: in-range → `PiStore`; out-of-range → `PiLiveLookupService`. Maintains a flat `lookupCache`.
- **`PiStore`** — Loads `pi_2026_2035_index.json` off the main thread via `Task.detached`. O(1) lookups by ISO date key.
- **`PiLiveLookupService`** — Hits `v2.api.pisearch.joshkeegan.co.uk` for all formats in parallel (`withThrowingTaskGroup`). Also used by `FreeSearchViewModel` for arbitrary digit sequences.
- **`PreferencesStore`** — `@Observable` appearance store injected as `@Environment`. Separate from `AppViewModel` so widgets and views without the full VM can read it.
- **`DateStringGenerator`** — Pure value type. Both the repository layer and live lookup service use it to avoid duplication.

## Key Patterns

- **`@Observable` over `ObservableObject`**: Fine-grained dependency tracking — a view re-renders only when a property it *reads* changes. No `@Published` anywhere.
- **Repository pattern for testability**: `AppViewModel.init` accepts `(any PiRepository)?`; tests inject a mock. `PiStore` and `PiLiveLookupService` are never referenced directly by the ViewModel.
- **Async loading**: `AppViewModel.init` fires `Task { await self.load() }`. `load()` calls `repository.loadBundledIndex()` off the main thread. `isLoading = true` until load completes.
- **Out-of-range dates**: Years outside the bundled index trigger a live API call via `PiLiveLookupService`. `headerStatusText` distinguishes `source == .live` from `.bundled`.
- **Cancellable lookups**: `scheduleSelectionRefresh()` cancels any in-flight `lookupTask` before starting a new one, preventing stale results from clobbering the current selection.
- **Bounded month cache**: `AppViewModel` keeps up to 6 month summaries (LRU eviction). Cache hits only update the selected-state flag, avoiding a full rebuild.
- **Canvas layout cache**: `PiCanvasView` caches the expensive `PiBodyLayout` in a `@State` tuple, keyed on `(size, exactQuery, activeFormat, fontStyle, digitSize, excerpt)`. Only rebuilds when an input actually changes.
- **DateFormatters**: All `DateFormatter` instances are `private static let` cached properties — never allocated per render call.
- **Today indicator**: `AppViewModel.today` is set at init. Calendar cells draw an accent-colored ring on today's date when it is not also the selected date.
- **StoreKit review prompt**: Fired after 7 distinct dates are navigated AND the app has been open for ≥2 minutes (gated by `firstLaunchDate` in UserDefaults). `AppViewModel` sets `shouldPromptForRating = true`; `MainView` observes it and calls `@Environment(\.requestReview)`.
- **Share card**: `ShareableCard` conforms to `Transferable`. `ShareLink` renders it as a PNG via `ImageRenderer` in `ShareCardView`. The caller passes the active `ThemePalette` so the card matches the user's chosen theme.
- **Swipe gestures on canvas**: Left/right → previous/next day. Swipe-up (v > 50pt, more vertical than horizontal) → opens the Detail sheet.
- **Sheet backgrounds (iOS 26)**: All sheets conditionally skip setting a custom background on iOS 26+, letting the native Liquid Glass material show through. On iOS < 26 the theme background is painted explicitly.
- **preferredColorScheme**: `AppTheme.preferredColorScheme` returns `.dark` for Slate/Coppice/Aurora, `.light` for Frost/Ember, and `nil` for Custom (follows system). Applied at the `WindowGroup` level in `PiDayApp`.
- **Heat-map colors**: All calendar heat-map fills live in `ThemePalette` (`.heatNone/.faint/.cool/.warm/.hot/.heatOutOfMonth/.heatOutOfMonthForeground`) with per-theme dark-adapted variants. `PiPalette` no longer owns these.
- **Accessibility**: Canvas has `accessibilityHint` directing users to day navigation and detail sheet. Month-nav buttons use 44pt tap targets. `accessibilityReduceMotion` skips the reveal spring and symbol bounce effects. `FreeSearchView` has a keyboard toolbar dismiss button for `.numberPad`.
- **FreeSearch debounce**: 400ms Task-based debounce with `Task.isCancelled` checked both before the network call and after it returns, preventing stale results from overwriting cleared state.

## Pi Index Data Pipeline

The bundled resource `PiDay/Resources/pi_2026_2035_index.json` covers years 2026–2035 and is precomputed offline — it is **not** fetched at runtime.

To regenerate it:
1. `Scripts/generate_exact_index.py` — queries the PiSearch API for all date sequences across 5 billion digits. Outputs raw matches.
2. `Scripts/generate_pi_index.swift` — processes raw matches into the structured `PiIndexPayload` JSON (grouped by ISO date, with excerpts).

## Key Design Details

**Heat levels** are based on the best (earliest) position across all searched formats:
- Hot: position < 1,000
- Warm: < 100,000
- Cool: < 10,000,000
- Faint: anything beyond that

**Date formats searched** (`DateFormatOption`): `YYYYMMDD`, `DDMMYYYY`, `MMDDYYYY`, `YYMMDD`, `D/M/YYYY` (no leading zeros). The preference (`SearchFormatPreference`) can be set to International, American, ISO 8601, or All.

**Indexing convention**: Users can toggle between 1-based (first digit after decimal = position 1) and 0-based. This is a display offset applied in `IndexingConvention.displayPosition(for:)`.

**Themes**: `AppTheme` enum with `ThemePalette` color tokens. `PreferencesStore.resolvedPalette` is the single call site views use. Custom accent color is stored as three `Double` components in `UserDefaults` (not `Color`, which is not `Codable`).

**Notifications**: `NotificationService` is a static enum (no instance needed). Schedules a repeating annual notification for March 14 at 9:14 AM.

## Configuration

- Bundle ID: `academy.glasscode.piday`
- Deployment target: iOS 17.0
- Supports iPhone and iPad (portrait + landscape)
- Automatic code signing
