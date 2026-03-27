import WidgetKit
import Foundation
import SwiftUI

// WHY: The provider is the bridge between your data sources and the timeline.
// It answers three questions WidgetKit asks:
//   1. "Give me something to show RIGHT NOW while I set up" → placeholder()
//   2. "Give me the best data you can for the widget gallery" → getSnapshot()
//   3. "Give me a full schedule of entries and tell me when to reload" → getTimeline()
//
// All three methods must complete quickly. getTimeline() can do file I/O
// because WidgetKit calls it on a background thread.

struct PiDayProvider: AppIntentTimelineProvider {
    private let appGroupID = "group.academy.glasscode.piday"
    private let themeKey = "academy.glasscode.piday.pref.theme"
    private let appearanceModeKey = "academy.glasscode.piday.pref.appearanceMode"
    private let searchPreferenceKey = "academy.glasscode.piday.searchPreference"
    private let indexingConventionKey = "academy.glasscode.piday.indexingConvention"
    private let accentRKey = "academy.glasscode.piday.pref.accentR"
    private let accentGKey = "academy.glasscode.piday.pref.accentG"
    private let accentBKey = "academy.glasscode.piday.pref.accentB"

    // MARK: - TimelineProvider

    // placeholder() MUST be instant — it's called on the main thread.
    // Return hardcoded fake data that has the same shape as real data.
    func placeholder(in context: Context) -> PiDayEntry {
        .placeholder
    }

    // getSnapshot() is shown in the widget gallery and when adding a widget.
    // If context.isPreview is true, return fake data quickly.
    // Otherwise, do a real lookup — users pick their widget based on this preview.
    func snapshot(for configuration: WidgetThemeIntent, in context: Context) async -> PiDayEntry {
        if context.isPreview {
            return .placeholder
        } else {
            return buildEntry(configuration: configuration)
        }
    }

    // getTimeline() is the main workhorse — called periodically by WidgetKit.
    // We return one entry for today and tell WidgetKit to reload at midnight.
    // WHY one entry: the pi result for a given date never changes, so there's
    // nothing to animate within a day. At midnight a new day starts, so we need
    // fresh data then.
    func timeline(for configuration: WidgetThemeIntent, in context: Context) async -> Timeline<PiDayEntry> {
        let entry = buildEntry(configuration: configuration)
        // Reload policy: .after(date) tells WidgetKit "call getTimeline() again
        // no earlier than this date." We schedule it for the next midnight so
        // the widget shows tomorrow's date as soon as the day rolls over.
        let reloadAt = Calendar.current.nextMidnight(after: Date())
        return Timeline(entries: [entry], policy: .after(reloadAt))
    }

    // MARK: - Entry builder

    // Synchronous because PiStore.load(from:) is synchronous file I/O.
    // WidgetKit calls getTimeline() on a background thread, so blocking is fine.
    private func buildEntry(
        for date: Date = Date(),
        configuration: WidgetThemeIntent
    ) -> PiDayEntry {
        let today = displayedDate(relativeTo: date)
        let resolvedTheme = resolveTheme(from: configuration)
        let resolvedAppearance = resolveAppearance(from: configuration)
        let palette = resolvedTheme.palette(customAccent: customAccent, colorScheme: resolvedAppearance)
        let preference = resolveSearchPreference()
        let indexingConvention = resolveIndexingConvention()

        guard let store = Self.cachedStore else {
            return PiDayEntry(date: today, result: .outOfRange, palette: palette, preferredColorScheme: resolvedAppearance)
        }

        guard let metadata = store.payload?.metadata else {
            return PiDayEntry(date: today, result: .outOfRange, palette: palette, preferredColorScheme: resolvedAppearance)
        }

        // Check that today falls within the bundled year range.
        let year = Calendar.current.component(.year, from: today)
        guard year >= metadata.startYear && year <= metadata.endYear else {
            return PiDayEntry(date: today, result: .outOfRange, palette: palette, preferredColorScheme: resolvedAppearance)
        }

        let summary = store.summary(for: today, formats: preference.formats)
        let stats = store.stats

        // For the large widget, we pre-compute results for the next 4 days.
        var upcoming: [Date: PiDayEntry.EntryResult] = [:]
        for i in 1...4 {
            if let nextDate = Calendar.current.date(byAdding: .day, value: i, to: today) {
                let nextSummary = store.summary(for: nextDate, formats: preference.formats)
                if let best = nextSummary.bestMatch {
                    upcoming[nextDate] = .found(
                        query: best.query,
                        format: best.format,
                        storedPosition: indexingConvention.displayPosition(for: best.storedPosition),
                        excerpt: makeExcerpt(from: best.excerpt, query: best.query, storedPosition: best.storedPosition, excerptRadius: metadata.excerptRadius)
                    )
                } else {
                    let nextHero = DateStringGenerator().strings(for: nextDate, formats: [preference.heroFormat]).first?.1 ?? ""
                    upcoming[nextDate] = .notFound(heroQuery: nextHero, format: preference.heroFormat)
                }
            }
        }

        if let best = summary.bestMatch {
            let excerpt = makeExcerpt(
                from: best.excerpt,
                query: best.query,
                storedPosition: best.storedPosition,
                excerptRadius: metadata.excerptRadius
            )
            return PiDayEntry(
                date: today,
                result: .found(
                    query: best.query,
                    format: best.format,
                    storedPosition: indexingConvention.displayPosition(for: best.storedPosition),
                    excerpt: excerpt
                ),
                upcomingResults: upcoming,
                stats: stats,
                palette: palette,
                preferredColorScheme: resolvedAppearance
            )
        } else {
            let generator = DateStringGenerator()
            let heroQuery = generator.strings(for: today, formats: [preference.heroFormat]).first?.1 ?? ""
            return PiDayEntry(
                date: today,
                result: .notFound(heroQuery: heroQuery, format: preference.heroFormat),
                upcomingResults: upcoming,
                stats: stats,
                palette: palette,
                preferredColorScheme: resolvedAppearance
            )
        }
    }

    private func displayedDate(relativeTo date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func resolveTheme(from configuration: WidgetThemeIntent) -> AppTheme {
        if let configuredTheme = configuration.theme?.appTheme {
            return configuredTheme
        }

        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard
            let raw = defaults.string(forKey: themeKey),
            let theme = AppTheme(rawValue: raw)
        else {
            return .frost
        }
        return theme
    }

    private func resolveAppearance(from configuration: WidgetThemeIntent) -> ColorScheme? {
        if let appearance = configuration.appearance, appearance != .matchApp {
            return appearance.preferredColorScheme
        }

        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard
            let raw = defaults.string(forKey: appearanceModeKey),
            let mode = AppAppearanceMode(rawValue: raw)
        else {
            return nil
        }
        return mode.preferredColorScheme
    }

    private func resolveSearchPreference() -> SearchFormatPreference {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard
            let raw = defaults.string(forKey: searchPreferenceKey),
            let preference = SearchFormatPreference(rawValue: raw)
        else {
            return .international
        }
        return preference
    }

    private func resolveIndexingConvention() -> IndexingConvention {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard
            let raw = defaults.string(forKey: indexingConventionKey),
            let convention = IndexingConvention(rawValue: raw)
        else {
            return .oneBased
        }
        return convention
    }

    private var customAccent: Color {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let r = defaults.double(forKey: accentRKey)
        let g = defaults.double(forKey: accentGKey)
        let b = defaults.double(forKey: accentBKey)
        guard r + g + b > 0 else {
            return Color.accentColor
        }
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Excerpt trimming

    // The stored excerpt is wide (excerptRadius chars on each side).
    // For the widget we only need a small window around the query.
    private func makeExcerpt(
        from fullExcerpt: String,
        query: String,
        storedPosition: Int,
        excerptRadius: Int
    ) -> WidgetExcerpt {
        // The query starts at offset min(excerptRadius, storedPosition - 1) within the excerpt.
        let queryOffset = min(excerptRadius, storedPosition - 1)
        let displayRadius = 10  // digits to show on each side in the widget

        guard
            queryOffset >= 0,
            queryOffset + query.count <= fullExcerpt.count
        else {
            return WidgetExcerpt(before: "", query: query, after: "")
        }

        let queryIdx = fullExcerpt.index(fullExcerpt.startIndex, offsetBy: queryOffset)
        let queryEnd = fullExcerpt.index(queryIdx, offsetBy: query.count)

        let beforeStart = fullExcerpt.index(
            queryIdx, offsetBy: -min(displayRadius, queryOffset),
            limitedBy: fullExcerpt.startIndex
        ) ?? fullExcerpt.startIndex

        let afterEnd = fullExcerpt.index(
            queryEnd, offsetBy: displayRadius,
            limitedBy: fullExcerpt.endIndex
        ) ?? fullExcerpt.endIndex

        return WidgetExcerpt(
            before: (beforeStart > fullExcerpt.startIndex ? "…" : "") + String(fullExcerpt[beforeStart..<queryIdx]),
            query: query,
            after: String(fullExcerpt[queryEnd..<afterEnd]) + (afterEnd < fullExcerpt.endIndex ? "…" : "")
        )
    }
}

private extension PiDayProvider {
    static let cachedStore: PiStore? = {
        guard let url = Bundle.main.url(forResource: "pi_2026_2035_index", withExtension: "json") else {
            return nil
        }

        let store = PiStore()
        do {
            try store.load(from: url)
            return store
        } catch {
            return nil
        }
    }()
}

// MARK: - Calendar helper

private extension Calendar {
    // Returns the start of tomorrow — the natural reload point for a daily widget.
    func nextMidnight(after date: Date) -> Date {
        let tomorrow = self.date(byAdding: .day, value: 1, to: date) ?? date
        return startOfDay(for: tomorrow)
    }
}
