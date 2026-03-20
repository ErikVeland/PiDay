# Code Review Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 11 issues identified in the Steve Jobs code review.

**Architecture:** Fixes are batched by file to minimize context switching. Each batch is independently verifiable.

**Tech Stack:** Swift 5.9, SwiftUI, @Observable, iOS 17+

---

### Task 1: Fix `isInBundledRange` sentinel + merge two-dictionary cache

**Files:**
- Modify: `PiDay/PiDay/Core/Repository/DefaultPiRepository.swift`

**What to change:**

1. Change `isInBundledRange` line 97: `guard let range = indexedYearRange else { return true }` → `return false`
   WHY: Before the JSON loads, `indexedYearRange` is nil. Returning `true` makes every date appear "in range", causing bundled lookups against an empty store → all-grey calendar flash. Returning `false` sends those dates through the live path which shows proper loading state.

2. Merge `lookupCache: [String: DateLookupSummary]` + `errorCacheTimestamps: [String: Date]` into one dictionary:
   ```swift
   private var cache: [String: (result: DateLookupSummary, cachedAt: Date?)] = [:]
   ```
   Update `summary(for:formats:)`:
   - Replace `if let cached = lookupCache[cacheKey]` with `if let entry = cache[cacheKey]`
   - TTL check: `if entry.result.errorMessage != nil, let cachedAt = entry.cachedAt, Date().timeIntervalSince(cachedAt) >= errorCacheTTL { cache.removeValue(forKey: cacheKey) } else { return entry.result }`
   - Store successes: `cache[cacheKey] = (result, nil)`
   - Store errors: `cache[cacheKey] = (result, Date())`
   Update `bundledSummary(for:formats:)`:
   - Replace `lookupCache[cacheKey]` with `cache[cacheKey]?.result`
   - Replace `lookupCache[cacheKey] = result` with `cache[cacheKey] = (result, nil)`
   Update `loadBundledIndex()`:
   - Replace `lookupCache.removeAll()` with `cache.removeAll()`
   Update `clearCache()`:
   - Replace both `removeAll()` calls with single `cache.removeAll()`
   Remove: `private var lookupCache`, `private var errorCacheTimestamps`, `private let errorCacheTTL` (keep TTL as local constant or inline)

**Verify:** Build succeeds, no compiler errors.

---

### Task 2: Fix DetailSheetView — remove embedded appearance card, fix duplicate label, fix indentation

**Files:**
- Modify: `PiDay/PiDay/Features/Detail/DetailSheetView.swift`

**What to change:**

1. In `body`, replace `appearanceCard(palette: palette)` with:
   ```swift
   // Single entry point — full preferences are in the Preferences sheet (gear icon).
   Button {
       showPreferences = true
   } label: {
       Label("Appearance & Preferences", systemImage: "paintpalette")
           .font(.subheadline.weight(.semibold))
           .frame(maxWidth: .infinity)
   }
   .buttonStyle(.bordered)
   .tint(palette.accent)
   ```

2. Delete the entire `private func appearanceCard(palette: ThemePalette) -> some View` function (lines 225–345).

3. Remove `private let twoColumnGrid` (no longer used after deleting appearanceCard).

4. Fix indentation bug in `reminderCard` — line 366 `viewModel.notificationAuthState = newState` is indented 2 spaces shallower than it should be. Fix it to align with line 365.

**Verify:** Build succeeds. Detail sheet shows result cards + action row + preferences button + reminder card. No appearance grid in the detail sheet.

---

### Task 3: Add `isAnimated` to `AppTheme`, remove hardcoded `== .matrix` checks in `PiCanvasView`, delete dead `preferredColorScheme`, clamp `piLeadDigits`, cache glyph width, add layout cache

**Files:**
- Modify: `PiDay/PiDay/Core/Domain/AppTheme.swift`
- Modify: `PiDay/PiDay/Features/Canvas/PiCanvasView.swift`

**Step 1: AppTheme.swift**

1. Delete the dead property `var preferredColorScheme: ColorScheme? { nil }` (lines 292–294) and its comment.

2. Add after `var isDark: Bool`:
   ```swift
   // Whether this theme uses the per-character animated canvas renderer.
   // Views check this instead of comparing against the .matrix case directly,
   // keeping the view decoupled from the theme enum.
   var isAnimated: Bool { self == .matrix }
   ```

**Step 2: PiCanvasView.swift**

1. Replace both `preferences.theme == .matrix` occurrences with `preferences.theme.isAnimated`:
   - Line 92: `if preferences.theme == .matrix {` → `if preferences.theme.isAnimated {`
   - Line 522: `if preferences.theme == .matrix {` → `if preferences.theme.isAnimated {`

2. Fix `piLeadDigits` — clamp to `piBase.count` instead of repeating wrong digits:
   ```swift
   private func piLeadDigits(count: Int) -> String {
       String(Self.piBase.prefix(min(count, Self.piBase.count)))
   }
   ```
   WHY: The original appended repeating "31415926" for large canvases. That string is not Pi after the 8th digit. Pi enthusiasts will notice. Clamping at the known-correct boundary is honest.

3. Add glyph width cache and layout cache as `@State` properties. Add these to the struct (after `let revealSequence: Bool`):
   ```swift
   // Glyph width is expensive to compute (UIFont alloc + NSString.size).
   // Cache it and only recompute when the font parameters change.
   @State private var glyphWidthCache: GlyphWidthCache? = nil
   // Layout is expensive to compute (row × column iteration + string slicing).
   // Cache it and only recompute when layout inputs change.
   @State private var bodyLayoutCache: BodyLayoutCache? = nil
   ```

   Add these private structs at the bottom of the file (before the closing `}`):
   ```swift
   private struct GlyphWidthCache {
       let fontStyle: AppFontStyle
       let weight: AppFontWeight
       let digitSize: DigitSize
       let fontSize: CGFloat
       let width: CGFloat
   }

   private struct BodyLayoutCache {
       let size: CGSize
       let query: String
       let format: DateFormatOption
       let fontStyle: AppFontStyle
       let weight: AppFontWeight
       let digitSize: DigitSize
       let layout: PiBodyLayout
   }
   ```

4. Replace `measuredGlyphWidth(for:)` with a cached version. Change `digitContextBody` to use the layout cache, and `textMetrics` to use the glyph cache:

   In `textMetrics(for:queryLength:)`, replace the line:
   ```swift
   let glyphWidth = max(1, measuredGlyphWidth(for: bodyFontSize) + 0.8)
   ```
   with:
   ```swift
   let glyphWidth = max(1, cachedGlyphWidth(for: bodyFontSize) + 0.8)
   ```

   Replace `measuredGlyphWidth(for:)` with:
   ```swift
   private func cachedGlyphWidth(for fontSize: CGFloat) -> CGFloat {
       if let c = glyphWidthCache,
          c.fontStyle == preferences.fontStyle,
          c.weight == preferences.fontWeight,
          c.digitSize == preferences.digitSize,
          c.fontSize == fontSize {
           return c.width
       }
       let width = measuredGlyphWidth(for: fontSize)
       glyphWidthCache = GlyphWidthCache(
           fontStyle: preferences.fontStyle,
           weight: preferences.fontWeight,
           digitSize: preferences.digitSize,
           fontSize: fontSize,
           width: width
       )
       return width
   }

   private func measuredGlyphWidth(for fontSize: CGFloat) -> CGFloat {
       let uiFont = preferences.fontStyle.uiFont(size: fontSize, weight: preferences.fontWeight.fontWeight)
       let sample = "0" as NSString
       let attributes: [NSAttributedString.Key: Any] = [.font: uiFont]
       return ceil(sample.size(withAttributes: attributes).width)
   }
   ```

   In `digitContextBody(in:metrics:palette:)`, replace:
   ```swift
   let layout = makeBodyLayout(in: size, metrics: metrics)
   ```
   with:
   ```swift
   let layout = cachedBodyLayout(in: size, metrics: metrics)
   ```

   Add `cachedBodyLayout` function:
   ```swift
   private func cachedBodyLayout(in size: CGSize, metrics: PiTextMetrics) -> PiBodyLayout {
       let query = viewModel.exactQuery
       let format = viewModel.activeFormat
       if let c = bodyLayoutCache,
          c.size == size,
          c.query == query,
          c.format == format,
          c.fontStyle == preferences.fontStyle,
          c.weight == preferences.fontWeight,
          c.digitSize == preferences.digitSize {
           return c.layout
       }
       let layout = makeBodyLayout(in: size, metrics: metrics)
       bodyLayoutCache = BodyLayoutCache(
           size: size,
           query: query,
           format: format,
           fontStyle: preferences.fontStyle,
           weight: preferences.fontWeight,
           digitSize: preferences.digitSize,
           layout: layout
       )
       return layout
   }
   ```

**Verify:** Build succeeds. Matrix theme still animates. Non-matrix themes use static body text. Layout is not rebuilt unless inputs change.

---

### Task 4: Deduplicate `sortMatches`, fix FreeSearch debounce gap

**Files:**
- Modify: `PiDay/PiDay/Core/Domain/PiMatch.swift`
- Modify: `PiDay/PiDay/Core/Repository/PiStore.swift`
- Modify: `PiDay/PiDay/Core/Repository/PiLiveLookupService.swift`
- Modify: `PiDay/PiDay/Features/FreeSearch/FreeSearchView.swift`

**Step 1: Move `sortMatches` to `PiMatchResult`**

In `PiMatch.swift`, add to the `PiMatchResult` struct:
```swift
static func sortByPosition(_ left: PiMatchResult, _ right: PiMatchResult) -> Bool {
    switch (left.storedPosition, right.storedPosition) {
    case let (lhs?, rhs?): return lhs < rhs
    case (_?, nil):        return true
    case (nil, _?):        return false
    case (nil, nil):       return left.format.displayName < right.format.displayName
    }
}
```

**Step 2: Update callers**

In `PiStore.swift`, replace `.sorted(by: Self.sortMatches)` with `.sorted(by: PiMatchResult.sortByPosition)` and delete the private `sortMatches` function.

In `PiLiveLookupService.swift`, replace `matches.sort(by: sortMatches)` with `matches.sort(by: PiMatchResult.sortByPosition)` and delete the private `sortMatches` function.

**Step 3: Fix FreeSearch debounce gap**

In `FreeSearchView.swift`, in `resultArea`, change:
```swift
} else if searchVM.query.isEmpty {
    hintCard(palette: palette)
}
```
to:
```swift
} else {
    hintCard(palette: palette)
}
```
WHY: When query has ≥3 digits and the debounce timer is running (not yet loading, hasn't searched), none of the previous conditions match and the area goes blank. The hint card is always appropriate when there's no result or error — for 1-2 digit queries the input field already shows "Enter at least 3 digits".

**Verify:** Build succeeds. In FreeSearch, typing digits immediately shows the hint card (then transitions to loading spinner in input field, then result/not-found). Clearing input still shows hint. Sorting in PiStore and PiLiveLookupService matches the shared implementation.
