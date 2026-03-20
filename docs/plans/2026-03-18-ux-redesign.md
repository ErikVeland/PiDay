# PiDay UX Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 11 UX issues identified in the review: result strip, not-found state, confetti, icon fix, bookmark promotion, preferences push nav, heat map legend.

**Architecture:** Pure UI layer — no model or repository changes. New views (`ResultStripView`, `ConfettiView`) composited into `MainView` via ZStack overlay. `PreferencesView` converted from sheet to push navigation. `AppViewModel` gains one derived property (`resultHeatLevel`).

**Tech Stack:** SwiftUI (@Observable, NavigationStack, Canvas, TimelineView), UIKit (UIPasteboard, haptics via sensoryFeedback)

**Build command:** `xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20`

---

### Task 1 — AppViewModel: add `resultHeatLevel`

**Files:**
- Modify: `PiDay/Features/Main/AppViewModel.swift` (after line 243 — end of derived properties block)

**Why:** `ResultStripView` needs to display "Hot/Warm/Cool/Faint" next to the position. The thresholds match the existing calendar heat-map thresholds defined in CLAUDE.md.

**Step 1: Add the computed property**

Insert after the `headerStatusText` property (around line 244), before `detailShareText`:

```swift
/// Heat level of the best match for display in the result strip.
/// Mirrors the calendar heat-map thresholds (position is display-convention-adjusted).
var resultHeatLevel: PiHeatLevel {
    guard let pos = bestMatch?.storedPosition else { return .none }
    let displayed = displayedPosition(for: pos)
    if displayed < 1_000     { return .hot }
    if displayed < 100_000   { return .warm }
    if displayed < 10_000_000 { return .cool }
    return .faint
}
```

**Step 2: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PiDay/Features/Main/AppViewModel.swift
git commit -m "feat: add resultHeatLevel derived property to AppViewModel"
```

---

### Task 2 — Create `ResultStripView`

**Files:**
- Create: `PiDay/Features/Main/ResultStripView.swift`

**Why:** The strip sits between the canvas and bottom controls, always visible, showing date / position / heat. Long-press opens a context menu. This is the primary fix for "result buried in Detail sheet."

**Step 1: Create the file**

```swift
import SwiftUI

// WHY separate file: ResultStripView is a distinct UI component with its own
// context-menu logic. Keeping it out of MainView preserves MainView's role as
// a pure coordinator.

struct ResultStripView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let onFreeSearch: () -> Void

    var body: some View {
        let palette = preferences.resolvedPalette
        HStack(spacing: 0) {
            dateLabel(palette: palette)
            Spacer(minLength: 12)
            resultLabel(palette: palette)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        // Long-press reveals quick actions without opening the Detail sheet.
        .contextMenu { contextMenuItems(palette: palette) }
    }

    // MARK: - Subviews

    private func dateLabel(palette: ThemePalette) -> some View {
        Text(shortDate(viewModel.selectedDate))
            .foregroundStyle(palette.ink.opacity(0.85))
            .lineLimit(1)
    }

    @ViewBuilder
    private func resultLabel(palette: ThemePalette) -> some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(palette.mutedInk)
                .scaleEffect(0.75)
        } else if viewModel.errorMessage != nil {
            Label("Error", systemImage: "exclamationmark.wifi")
                .foregroundStyle(PiPalette.error)
                .lineLimit(1)
        } else if let match = viewModel.bestMatch {
            HStack(spacing: 6) {
                // AnimatedCounterView already exists — reuse it for the rolling number.
                HStack(spacing: 0) {
                    Text("digit ")
                    AnimatedCounterView(target: viewModel.displayedPosition(for: match.storedPosition))
                }
                .foregroundStyle(palette.ink.opacity(0.85))

                Text("·")
                    .foregroundStyle(palette.mutedInk)

                Text(heatLabel)
                    .foregroundStyle(heatColor(palette: palette))
            }
            .lineLimit(1)
        } else if viewModel.isSelectedDateInRange {
            Text("Not found in π")
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
        } else {
            Text("Searching live…")
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func contextMenuItems(palette: ThemePalette) -> some View {
        // Bookmark
        Button {
            viewModel.toggleSaveCurrentDate()
        } label: {
            Label(
                viewModel.isCurrentDateSaved ? "Remove Bookmark" : "Bookmark",
                systemImage: viewModel.isCurrentDateSaved ? "bookmark.slash" : "bookmark"
            )
        }

        // Share
        if let match = viewModel.bestMatch {
            ShareLink(
                item: viewModel.shareableCard(palette: palette),
                preview: SharePreview("PiDay", image: Image(systemName: "chart.bar.doc.horizontal"))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            // Copy position
            Button {
                let pos = viewModel.displayedPosition(for: match.storedPosition)
                UIPasteboard.general.string = "digit \(pos)"
            } label: {
                Label("Copy Position", systemImage: "doc.on.doc")
            }
        }

        // Free search
        Button { onFreeSearch() } label: {
            Label("Search Pi Digits", systemImage: "magnifyingglass")
        }
    }

    // MARK: - Helpers

    private var heatLabel: String {
        switch viewModel.resultHeatLevel {
        case .hot:   return "Hot"
        case .warm:  return "Warm"
        case .cool:  return "Cool"
        case .faint: return "Faint"
        case .none:  return ""
        }
    }

    private func heatColor(palette: ThemePalette) -> Color {
        switch viewModel.resultHeatLevel {
        case .hot:   return palette.heatHot
        case .warm:  return palette.heatWarm
        case .cool:  return palette.heatCool
        case .faint: return palette.heatFaint
        case .none:  return palette.mutedInk
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private func shortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PiDay/Features/Main/ResultStripView.swift
git commit -m "feat: add ResultStripView — always-visible result strip with context menu"
```

---

### Task 3 — Create `ConfettiView`

**Files:**
- Create: `PiDay/Features/Main/ConfettiView.swift`

**Why:** Brief particle burst when a match resolves. Uses `TimelineView` + `Canvas` so no third-party deps. Respects `accessibilityReduceMotion`. Driven by an integer `trigger` — incrementing it fires one burst.

**Step 1: Create the file**

```swift
import SwiftUI

// WHY TimelineView + Canvas: declarative particles without UIKit.
// Canvas draws all particles in one pass — no SwiftUI view per particle, no layout overhead.
// WHY trigger: Int (not Bool): an Int increment always fires onChange even when
// rapidly re-triggered (Bool toggle could collide if two matches resolve quickly).

struct ConfettiView: View {
    let trigger: Int
    let palette: ThemePalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var startTime: Date? = nil
    private let duration: Double = 0.85
    private let particleCount = 48

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: startTime == nil)) { context in
            let elapsed = startTime.map { context.date.timeIntervalSince($0) } ?? 0
            Canvas { ctx, size in
                guard elapsed < duration else { return }
                drawParticles(ctx: ctx, size: size, elapsed: elapsed)
            }
            .allowsHitTesting(false)
        }
        // WHY task(id: trigger): fires whenever trigger increments, replacing any
        // in-flight animation (previous start time is overwritten).
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            startTime = .now
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.1) * 1_000_000_000))
            startTime = nil
        }
    }

    // MARK: - Drawing

    private func drawParticles(ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let progress = elapsed / duration                         // 0 → 1
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let colors: [Color] = [palette.day, palette.month, palette.year, palette.accent]

        for i in 0..<particleCount {
            let seed = Double(i * 7 + trigger * 13)
            let angle = noise(seed) * .pi * 2
            let speed = 0.28 + noise(seed + 1) * 0.38       // fraction of screen width
            let colorIndex = i % colors.count
            let size2 = 4 + noise(seed + 2) * 5             // 4–9 pt

            // Eased position: fast launch, gravity pull
            let t = min(1.0, progress * 1.6)                 // slightly faster than duration
            let easedT = t * t * (3 - 2 * t)                 // smoothstep
            let x = origin.x + cos(angle) * speed * easedT * size.width * 0.55
            let gravityY = progress * progress * size.height * 0.28
            let y = origin.y + sin(angle) * speed * easedT * size.height * 0.38 + gravityY

            // Opacity: full until 60%, then fade out
            let opacity = progress < 0.6 ? 1.0 : 1.0 - (progress - 0.6) / 0.4

            var gctx = ctx
            gctx.opacity = opacity
            let rect = CGRect(x: x - size2 / 2, y: y - size2 / 2, width: size2, height: size2)
            // Alternate between circles and rounded rects for variety
            let shape: Path = i % 3 == 0
                ? Path(ellipseIn: rect)
                : Path(roundedRect: rect, cornerRadius: 2)
            gctx.fill(shape, with: .color(colors[colorIndex]))
        }
    }

    // WHY deterministic noise (not Random): same trigger value = same burst pattern.
    // Prevents jarring visual jumps if the view re-renders between frames.
    private func noise(_ seed: Double) -> Double {
        let v = sin(seed * 12.9898 + 78.233) * 43758.5453
        return v - floor(v)
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PiDay/Features/Main/ConfettiView.swift
git commit -m "feat: add ConfettiView — particle burst on match resolution"
```

---

### Task 4 — MainView: wire strip + confetti + fix icon

**Files:**
- Modify: `PiDay/Features/Main/MainView.swift`

**Changes:**
1. Add `@State private var confettiTrigger = 0` and `@State private var showFreeSearch = false`
2. Add `ResultStripView` + `ConfettiView` into the ZStack
3. Replace `slider.horizontal.3` → `info.circle`
4. Add FreeSearch sheet
5. Add `.onChange` to fire confetti when a new match is found

**Step 1: Add new state properties**

After `@State private var detailsBounce = false` (line 28), add:

```swift
@State private var confettiTrigger = 0
@State private var showFreeSearch = false
```

**Step 2: Add ResultStripView and ConfettiView to ZStack**

Replace the existing `VStack { Spacer(); bottomControls... }` block (lines 46–50):

```swift
VStack(spacing: 0) {
    Spacer()
    ResultStripView(onFreeSearch: { showFreeSearch = true })
        .padding(.bottom, 6)
    bottomControls
        .padding(.bottom, 18)
}

// Confetti overlays the canvas; pointer events pass through (allowsHitTesting false in ConfettiView)
ConfettiView(trigger: confettiTrigger, palette: palette)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
```

**Step 3: Fix the Detail button icon**

On line 139, change:

```swift
systemName: "slider.horizontal.3",
accessibilityLabel: "Date format and settings",
```

to:

```swift
systemName: "info.circle",
accessibilityLabel: "Date details",
```

**Step 4: Add FreeSearch sheet**

After the `.sheet(isPresented: $showDetails)` block (line 65), add:

```swift
.sheet(isPresented: $showFreeSearch) {
    FreeSearchView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
}
```

**Step 5: Fire confetti on new match**

After the `.onChange(of: viewModel.isLoading)` block (around line 103), add:

```swift
// Fire confetti when a lookup resolves with a new match position.
// WHY guard new != nil: don't fire when navigating away (match becomes nil).
// WHY old != new: skip if same position resolved twice (e.g. format change, same date).
.onChange(of: viewModel.bestMatch?.storedPosition) { old, new in
    guard new != nil, old != new else { return }
    confettiTrigger += 1
}
```

**Step 6: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```bash
git add PiDay/Features/Main/MainView.swift
git commit -m "feat: add result strip, confetti burst, fix info.circle icon in MainView"
```

---

### Task 5 — DetailSheetView: bookmark in action row + Preferences push nav

**Files:**
- Modify: `PiDay/Features/Detail/DetailSheetView.swift`

**Changes:**
1. Remove `@State private var showPreferences = false` (it becomes a NavigationLink destination)
2. Add Bookmark as a 4th button in the action row
3. Replace `.sheet(isPresented: $showPreferences)` with `.navigationDestination`
4. Change gear button to toggle a `@State private var navigateToPreferences = false`
5. Change "Appearance & Preferences" full-width button to also trigger navigation

**Step 1: Replace showPreferences state**

Change line 15:
```swift
@State private var showPreferences = false
```
to:
```swift
@State private var navigateToPreferences = false
```

**Step 2: Add Bookmark to the action row**

Replace the existing `HStack(spacing: 10)` action row (lines 44–73) with:

```swift
// Share · Search · Saved · Bookmark — four peer actions.
// WHY bookmark here (not toolbar only): promotes it from the most obscure toolbar
// location to an immediately visible action.
HStack(spacing: 8) {
    ShareLink(
        item: viewModel.shareableCard(palette: palette),
        preview: SharePreview("PiDay", image: Image(systemName: "chart.bar.doc.horizontal"))
    ) {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .tint(palette.accent)
    .disabled(viewModel.isLoading || viewModel.errorMessage != nil)

    Button { showFreeSearch = true } label: {
        Label("Search", systemImage: "magnifyingglass")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .tint(palette.accent)

    Button { showSavedDates = true } label: {
        Label("Saved", systemImage: "bookmark")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .tint(palette.accent)

    Button { viewModel.toggleSaveCurrentDate() } label: {
        Image(systemName: viewModel.isCurrentDateSaved ? "bookmark.fill" : "bookmark.badge.plus")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: 44)
            .contentTransition(.symbolEffect(.replace.offUp))
    }
    .buttonStyle(.bordered)
    .tint(viewModel.isCurrentDateSaved ? palette.accent : palette.accent)
    .accessibilityLabel(viewModel.isCurrentDateSaved ? "Remove bookmark" : "Bookmark date")
}
```

**Step 3: Update gear button in toolbar**

In the toolbar `ToolbarItem(placement: .topBarLeading)` block, change:
```swift
Button {
    showPreferences = true
} label: {
```
to:
```swift
Button {
    navigateToPreferences = true
} label: {
```

**Step 4: Replace "Appearance & Preferences" button**

Replace the standalone full-width Button for preferences (lines 75–83) with:

```swift
Button {
    navigateToPreferences = true
} label: {
    Label("Appearance & Preferences", systemImage: "paintpalette")
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(palette.accent)
```

**Step 5: Replace sheet with navigationDestination**

Remove the sheet block:
```swift
.sheet(isPresented: $showPreferences) {
    PreferencesView(isPresented: $showPreferences)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
}
```

Add navigationDestination inside the NavigationStack (after the `.toolbar` closing brace, before the closing brace of `NavigationStack`):

```swift
.navigationDestination(isPresented: $navigateToPreferences) {
    PreferencesView()
}
```

**Step 6: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: error about `PreferencesView(isPresented:)` — we fix that in Task 6.

---

### Task 6 — PreferencesView: remove @Binding, use @Environment(\.dismiss)

**Files:**
- Modify: `PiDay/Features/Preferences/PreferencesView.swift`

**Why:** With push navigation, `isPresented = false` doesn't pop — it only works for sheets. `@Environment(\.dismiss)` works for both sheets and push destinations, making PreferencesView usable in either context.

**Step 1: Replace @Binding with @Environment(\.dismiss)**

Change:
```swift
@Binding var isPresented: Bool
```
to:
```swift
@Environment(\.dismiss) private var dismiss
```

**Step 2: Update Done button**

Change:
```swift
Button("Done") { isPresented = false }
```
to:
```swift
Button("Done") { dismiss() }
```

**Step 3: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit Tasks 5 + 6 together**

```bash
git add PiDay/Features/Detail/DetailSheetView.swift PiDay/Features/Preferences/PreferencesView.swift
git commit -m "feat: promote bookmark to action row; Preferences as push nav in Detail sheet"
```

---

### Task 7 — PiCanvasView: not-found opacity

**Files:**
- Modify: `PiDay/Features/Canvas/PiCanvasView.swift`

**Why:** When a date has no match, the current fallback (repeated query pattern) looks identical to a real match. Fading the canvas to near-invisible makes the not-found state unmistakable. The result strip (Task 2) shows the "Not found" message.

**Step 1: Add a computed helper**

After the `focusGlow` function (around line 571), add:

```swift
// True when a lookup has completed with no match and no error.
// WHY exclude isLoading: we don't want to flash the faded state during the
// brief moment between navigation and lookup completion.
private var isNotFound: Bool {
    !viewModel.isLoading
    && viewModel.bestMatch == nil
    && viewModel.errorMessage == nil
    && viewModel.isSelectedDateInRange
}
```

**Step 2: Apply opacity in digitContextBody**

In `digitContextBody(in:metrics:palette:)`, find the `.frame(width: metrics.viewportWidth, alignment: .top).clipped()` block (around line 117). After `.clipped()`, add:

```swift
.opacity(isNotFound ? 0.08 : 1.0)
.animation(.easeInOut(duration: 0.3), value: isNotFound)
```

**Step 3: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add PiDay/Features/Canvas/PiCanvasView.swift
git commit -m "feat: fade canvas to 8% opacity when date has no pi match"
```

---

### Task 8 — CalendarSheetView: expanded legend

**Files:**
- Modify: `PiDay/Features/Calendar/CalendarSheetView.swift`

**Why:** The current legend (bare dots + labels) doesn't convey that colours represent speed/earliness in pi. Adding a directional "Earlier in Pi →" cue makes it self-explanatory.

**Step 1: Replace legendRow function**

Replace the existing `legendRow` function (lines 125–140) with:

```swift
private func legendRow(palette: ThemePalette) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        // Directional legend: left = not found / late, right = early / hot.
        HStack(spacing: 0) {
            Text("Not found")
                .font(.caption2)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            Spacer(minLength: 6)

            // The five heat dots with an arrow cue between Not found and Hot ends.
            HStack(spacing: 6) {
                Text("Later in π")
                    .font(.caption2)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                legendDot(palette.heatNone,  palette: palette)
                legendDot(palette.heatFaint, palette: palette)
                legendDot(palette.heatCool,  palette: palette)
                legendDot(palette.heatWarm,  palette: palette)
                legendDot(palette.heatHot,   palette: palette)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                Text("Earlier in π")
                    .font(.caption2)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            }
        }

        Text("Based on earliest position across all searched formats in the first 5B digits.")
            .font(.caption2)
            .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
    }
    .padding(.top, 4)
}

// WHY signature change: label param removed — dots are now unlabelled in the
// directional flow; context is provided by the surrounding "Later → Earlier" text.
private func legendDot(_ color: Color, palette: ThemePalette) -> some View {
    Circle()
        .fill(color)
        .frame(width: 10, height: 10)
}
```

**Important:** Also remove the old `legendDot` function that takes a `label:` parameter (lines 142–151), and update the call site that still uses it. Search for `legendDot(palette.heatNone, label:` — replace each call with the new signature (label removed).

**Step 2: Build**

```bash
xcodebuild -scheme PiDay -configuration Debug build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add PiDay/Features/Calendar/CalendarSheetView.swift
git commit -m "feat: expand calendar heat legend with Earlier/Later in Pi directional cues"
```

---

### Task 9 — Verify on simulator

**Step 1: Run on simulator**

```bash
xcodebuild -scheme PiDay -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

**Step 2: Manual smoke-test checklist**

- [ ] Main screen shows result strip below canvas, above controls
- [ ] Detail button shows `info.circle` (not slider icon)
- [ ] Confetti fires when navigating to a date that has a match
- [ ] Long-press on result strip shows context menu: Bookmark, Share, Copy Position, Search Pi Digits
- [ ] Detail sheet action row has 4 buttons: Share, Search, Saved, Bookmark
- [ ] Gear icon in Detail sheet toolbar → pushes Preferences (slide-in, not modal)
- [ ] "Appearance & Preferences" button in Detail sheet → same push
- [ ] Preferences "Done" button pops back (doesn't dismiss all sheets)
- [ ] Navigate to a date with no match → canvas fades to near-invisible
- [ ] Navigate back to a date with a match → canvas fades back in
- [ ] Calendar legend shows "Later in π → [dots] → Earlier in π"
- [ ] Edge-to-edge digits still flush at both screen edges across all font styles

**Step 3: Final commit if any fixups were needed**

```bash
git add -p  # stage only intentional fixups
git commit -m "fix: post-integration smoke-test fixups"
```

---

## Quick Reference — Changed Files

| File | Change |
|------|--------|
| `Features/Main/AppViewModel.swift` | +`resultHeatLevel: PiHeatLevel` |
| `Features/Main/ResultStripView.swift` | **NEW** — always-visible result strip |
| `Features/Main/ConfettiView.swift` | **NEW** — particle burst on match |
| `Features/Main/MainView.swift` | Wire strip+confetti; `info.circle` icon; freeSearch sheet |
| `Features/Detail/DetailSheetView.swift` | Bookmark in action row; prefs as push nav |
| `Features/Preferences/PreferencesView.swift` | `@Environment(\.dismiss)` replaces `@Binding` |
| `Features/Canvas/PiCanvasView.swift` | 0.08 opacity when not found |
| `Features/Calendar/CalendarSheetView.swift` | Directional legend |
