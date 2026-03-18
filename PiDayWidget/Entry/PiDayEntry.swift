import WidgetKit
import Foundation
import SwiftUI

// WHY: TimelineEntry is the data model for one rendered snapshot.
// The widget view receives exactly one Entry and renders it — no async loading,
// no ViewModel, just "here is the data, draw it."
//
// We model the result as an enum so the view knows *why* there's no match
// and can show the right message without nil-checking.

struct PiDayEntry: TimelineEntry {
    // Required by TimelineEntry: the date at which WidgetKit should display this entry.
    // For PiDay this is midnight — the start of the day we searched.
    let date: Date
    let result: EntryResult
    let palette: ThemePalette
    let preferredColorScheme: ColorScheme?

    // WHY relevance: the Smart Stack uses this score to decide which widget to surface.
    // A date that appears very early in pi (low position) is more remarkable and should
    // be promoted. Pi Day itself (March 14) gets the highest possible score.
    // score is in [0, 1]; duration tells WidgetKit how long this relevance is valid.
    var relevance: TimelineEntryRelevance? {
        switch result {
        case let .found(_, _, storedPosition, _):
            // log10(1) = 0 → score 1.0 (appears at digit 1 — maximum interest)
            // log10(10_000_000) = 7 → score 0.0 (very deep in pi — minimum interest)
            let score = Float(max(0.0, 1.0 - log10(Double(max(1, storedPosition))) / 7.0))
            return TimelineEntryRelevance(score: score, duration: 86_400)
        case .notFound, .outOfRange:
            return TimelineEntryRelevance(score: 0, duration: 86_400)
        }
    }

    enum EntryResult: Equatable {
        // Date found in pi — carries everything needed to render the result.
        case found(
            query: String,
            format: DateFormatOption,
            storedPosition: Int,
            // A short window of pi digits centered on the query, pre-sliced by the provider.
            // Pre-computing it here keeps the view pure: no string slicing in the view layer.
            excerpt: WidgetExcerpt
        )
        // Date not found in the bundled index for that format.
        case notFound(heroQuery: String, format: DateFormatOption)
        // Year is outside the bundled index range (e.g. before 2026 or after 2035).
        case outOfRange
    }
}

// WidgetExcerpt holds the three segments of the excerpt string.
// The view assembles them into a single styled Text without needing to know
// how they were computed.
struct WidgetExcerpt: Equatable {
    let before: String   // digits before the query  (e.g. "…41592653")
    let query: String    // the matching sequence    (e.g. "14032026")
    let after: String    // digits after the query   (e.g. "897932384…")
}

// MARK: - Sample data

extension PiDayEntry {
    // Used by placeholder() and Xcode previews.
    // Must be instant — no file I/O allowed.
    static let placeholder = PiDayEntry(
        date: Calendar.current.startOfDay(for: Date()),
        result: .found(
            query: "14032026",
            format: .ddmmyyyy,
            storedPosition: 47_832,
            excerpt: WidgetExcerpt(before: "…41592653", query: "14032026", after: "897932384…")
        ),
        palette: AppTheme.frost.palette(),
        preferredColorScheme: nil
    )

    static let notFoundSample = PiDayEntry(
        date: Calendar.current.startOfDay(for: Date()),
        result: .notFound(heroQuery: "01012099", format: .ddmmyyyy),
        palette: AppTheme.frost.palette(),
        preferredColorScheme: nil
    )

    static let outOfRangeSample = PiDayEntry(
        date: Calendar.current.startOfDay(for: Date()),
        result: .outOfRange,
        palette: AppTheme.frost.palette(),
        preferredColorScheme: nil
    )
}
