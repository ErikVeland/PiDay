# PiDay UX Redesign — Design Document
_2026-03-18_

## Context

Full UX review identified 11 issues across P0–P3 priority levels. This document captures the approved design decisions for all fixes.

## Core Framing

PiDay is first and foremost a **calendar app**. The canvas opens to today's date. Finding birthdays and other dates is a bonus feature. This framing shapes every decision below.

---

## 1. Result Strip (B2)

**Problem:** The position number ("digit 4,823,456") is buried in a tiny header and the Detail sheet. Users can't see their result without hunting.

**Solution:** A slim horizontal strip sits between the canvas and the bottom control bar. Always visible, no sheet required.

**Content:**
```
[ Mar 18, 2026  ·  digit 4,823,456  ·  🔥 Hot  ·  YYYYMMDD ]
```
- Left: formatted selected date
- Center: position with `AnimatedCounterView` (existing)
- Right: heat badge (Hot / Warm / Cool / Faint / —) + format label
- Not-found state: `"Not found in first 5 billion digits"` (see §3)

**Long-press (context menu):** Bookmark, Share, Copy Position, Free Search

**Edge-to-edge:** The canvas edge-to-edge guarantee is unaffected — the strip is a separate layout slot below the canvas, outside the `GeometryReader`.

---

## 2. Not-Found Canvas State

**Problem:** When a date isn't in 5B digits, the canvas repeats the query as decoration — indistinguishable from a real match.

**Solution (Option A):**
- All canvas digits drop to opacity ~0.08
- No highlighted row
- No repeated query pattern
- Result strip reads: `"Not found in first 5 billion digits"`

The canvas becomes visually quiet. The contrast with a found state is unmistakable.

---

## 3. Match Celebration

**Problem:** No moment of delight when a match resolves.

**Solution (Option B):** A `TimelineView`-driven particle burst (SwiftUI `Canvas`-based confetti) plays once over the canvas when `lookupSummary` resolves with a valid match.
- Duration: ~0.8s
- Respects `accessibilityReduceMotion` (instant snap, no confetti)
- Fires on same trigger as existing spring reveal
- Does NOT fire on navigation-only changes (prev/next day) — only when a new lookup resolves

---

## 4. Detail Button Icon

**Problem:** `slider.horizontal.3` reads as audio equalizer, not "see details."

**Solution:** Replace with `info.circle`.

---

## 5. Preferences Navigation

**Problem:** Preferences opens as a sheet from within the Detail sheet — two sheets stacked.

**Solution (Option A):** Preferences becomes a `.navigationDestination` push inside the Detail sheet's existing `NavigationStack`. Standard iOS slide-in transition. No sheet nesting.

Gear icon in the Detail sheet toolbar triggers `NavigationLink` to `PreferencesView`.

---

## 6. Bookmark Placement

**Problem:** Bookmark is in the Detail sheet toolbar — the most obscure location possible.

**Solution (Option B):** Move bookmark into the Detail sheet's action row as a fourth full-width button alongside Share, Free Search, Saved Dates.

Long-press on the result strip (§1) also exposes bookmark via context menu.

---

## 7. Calendar Heat Map Legend

**Problem:** The legend row is cryptic — bare dots with no directional cue.

**Solution (Option B):** Expand the legend to read:

```
Not found  ·  ← Later in Pi  [dots]  Earlier in Pi →  ·  Top 0.1%
```

No coach mark, no tutorial. Self-explanatory inline.

---

## 8. Font Weight Slider

**Decision:** Keep the existing 9-level slider (ultraLight → black). Power users value the granularity.

---

## What Is NOT Changing

- Canvas layout, Matrix theme, color coding, gradient mask
- All existing accessibility work
- Widget target
- Share card
- SavedDates flow (except bookmark button location)
- Notification flow
- Glyph width measurement and edge-to-edge overflow-clip strategy

---

## Edge-to-Edge Guarantee

The canvas edge-to-edge mechanism is confirmed sound:
```
viewportWidth = floor(size.width)
glyphWidth    = ceil(UIKit NSString.size) + 0.8   // measured per font/weight/size
columns       = alignedColumnCount(ceil(viewportWidth / glyphWidth), queryLength)
bodyWidth     = columns × glyphWidth              // ≥ viewportWidth, always
.frame(width: viewportWidth).clipped()            // hard cut
```
All four font styles are monospaced; UIKit measurement is authoritative; `+0.8` absorbs sub-pixel rounding. The result strip addition does not affect this — it is outside the canvas `GeometryReader`.

---

## Files Expected to Change

| File | Change |
|------|--------|
| `Features/Main/MainView.swift` | Add result strip view; wire confetti trigger |
| `Features/Canvas/PiCanvasView.swift` | Not-found opacity treatment |
| `Features/Detail/DetailSheetView.swift` | Icon swap; bookmark to action row; Preferences as push nav |
| `Features/Calendar/CalendarSheetView.swift` | Expanded legend row |
| `Features/Preferences/PreferencesView.swift` | Adjust for push nav context |
| New: `Features/Main/ConfettiView.swift` | Particle burst implementation |
| New: `Features/Main/ResultStripView.swift` | Result strip component |
