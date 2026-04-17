import Foundation

// WHY: The app can now operate on multiple "digit universes" (π, τ, e, φ, Planck).
// This protocol generalizes the repository contract so all features (detail lookup,
// calendar, stats, battles, share) can run against the currently-selected number.
//
// Requirement: no fake data.
// Therefore this repository is bundled-only (no live network fallback) unless we
// later add a real live search service for every constant.
@MainActor
protocol FeaturedNumberRepository {
    // Load all bundled indexes off the main thread. Call once at startup.
    func loadBundledIndexes() async throws

    // The year range covered by the bundled index for a given featured number.
    func indexedYearRange(for featuredNumber: CalendarFeaturedNumber) -> ClosedRange<Int>?

    // Excerpt radius from the index metadata (used for canvas display).
    func excerptRadius(for featuredNumber: CalendarFeaturedNumber) -> Int

    // Computed statistics from the bundled index.
    func stats(for featuredNumber: CalendarFeaturedNumber) -> PiStats?

    // Look up a date (bundled-only). Returns an empty summary when out of range.
    func summary(for featuredNumber: CalendarFeaturedNumber, date: Date, formats: [DateFormatOption]) -> DateLookupSummary

    // Clears any in-memory caches after a settings change.
    func clearCache()
}

