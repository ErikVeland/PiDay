import Foundation

// WHY: DefaultPiRepository is the concrete implementation of PiRepository.
// It owns the routing decision: "is this date in our bundled range, or do we
// need to call the live API?" That decision lives here — not in the ViewModel.
//
// The ViewModel asks: "give me a summary for this date."
// The repository answers — the ViewModel never knows which source was used
// (except that it's encoded in the returned DateLookupSummary.source).

@MainActor
final class DefaultPiRepository: PiRepository {
    private let store = PiStore()
    private let liveLookup = PiLiveLookupService()
    private let generator = DateStringGenerator()
    private var lookupCache: [String: DateLookupSummary] = [:]
    private var errorCacheTimestamps: [String: Date] = [:]
    private let errorCacheTTL: TimeInterval = 60

    // WHY nonisolated init: stored properties all have nonisolated inline initializers
    // (PiStore, PiLiveLookupService, DateStringGenerator carry no actor annotation).
    // A nonisolated init lets AppViewModel.init (also nonisolated) construct the
    // default repository without needing to already be on the main actor.
    nonisolated init() {}

    var indexedYearRange: ClosedRange<Int>? {
        guard let metadata = store.payload?.metadata else { return nil }
        return metadata.startYear...metadata.endYear
    }

    var excerptRadius: Int {
        store.payload?.metadata.excerptRadius ?? 20
    }

    func loadBundledIndex() async throws {
        try await store.loadInBackground()
        lookupCache.removeAll()
    }

    func summary(for date: Date, formats: [DateFormatOption]) async -> DateLookupSummary {
        let cacheKey = cacheKey(for: date, formats: formats)
        if let cached = lookupCache[cacheKey] {
            // For error entries, only serve from cache if within the TTL window.
            if cached.errorMessage != nil,
               let cachedAt = errorCacheTimestamps[cacheKey],
               Date().timeIntervalSince(cachedAt) >= errorCacheTTL {
                lookupCache.removeValue(forKey: cacheKey)
                errorCacheTimestamps.removeValue(forKey: cacheKey)
            } else {
                return cached
            }
        }

        let result: DateLookupSummary
        if isInBundledRange(date) {
            result = store.summary(for: date, formats: formats)
        } else {
            do {
                result = try await liveLookup.summary(for: date, formats: formats)
            } catch {
                // On live error, return a "not found" summary so the UI can show the error separately.
                let isoDate = generator.isoDateString(for: date)
                let queries = generator.strings(for: date, formats: formats)
                result = DateLookupSummary(
                    isoDate: isoDate,
                    matches: queries.map { format, query in
                        PiMatchResult(query: query, format: format, found: false, storedPosition: nil, excerpt: nil)
                    },
                    bestMatch: nil,
                    source: .live,
                    errorMessage: error.localizedDescription
                )
            }
        }

        if result.errorMessage == nil {
            lookupCache[cacheKey] = result
            errorCacheTimestamps.removeValue(forKey: cacheKey)
        } else {
            lookupCache[cacheKey] = result
            errorCacheTimestamps[cacheKey] = Date()
        }
        return result
    }

    // Bundled-only lookup for the calendar heat map.
    // Fast, synchronous — never hits the network.
    func bundledSummary(for date: Date, formats: [DateFormatOption]) -> DateLookupSummary {
        let cacheKey = cacheKey(for: date, formats: formats)
        if let cached = lookupCache[cacheKey], cached.source == .bundled { return cached }
        let result = store.summary(for: date, formats: formats)
        lookupCache[cacheKey] = result
        return result
    }

    func isInBundledRange(_ date: Date) -> Bool {
        guard let range = indexedYearRange else { return true }
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: date)
        return range.contains(year)
    }

    func clearCache() {
        lookupCache.removeAll()
        errorCacheTimestamps.removeAll()
    }

    private func cacheKey(for date: Date, formats: [DateFormatOption]) -> String {
        let iso = generator.isoDateString(for: date)
        let formatKey = formats.map(\.rawValue).sorted().joined(separator: ",")
        return "\(iso)-\(formatKey)"
    }
}
