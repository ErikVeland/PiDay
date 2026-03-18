import Foundation

// WHY: A protocol defines the "contract" — what the ViewModel needs, not how it's
// done. This is the key to testability: in tests you can swap in a MockPiRepository
// that returns canned results instantly, with no file I/O or network.
//
// The ViewModel only talks to this protocol, never to PiStore or PiLiveLookupService directly.
@MainActor
protocol PiRepository {
    // Whether a given date falls within the bundled index range.
    func isInBundledRange(_ date: Date) -> Bool

    // The year range covered by the bundled index.
    var indexedYearRange: ClosedRange<Int>? { get }

    // The excerpt radius from index metadata (used for canvas display).
    var excerptRadius: Int { get }

    // Load the bundled index off the main thread. Call once at startup.
    func loadBundledIndex() async throws

    // Look up a date. Automatically routes to bundled or live depending on the year.
    func summary(for date: Date, formats: [DateFormatOption]) async -> DateLookupSummary

    // Bundled-only lookup used for month summaries. Never performs network I/O.
    func bundledSummary(for date: Date, formats: [DateFormatOption]) -> DateLookupSummary

    // Clears any in-memory caches after a settings change.
    func clearCache()
}
