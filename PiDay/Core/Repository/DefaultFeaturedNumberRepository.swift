import Foundation

// Bundled-only repository for all calendar featured numbers.
//
// It reuses PiStore + PiIndexPayload (the on-disk format) for every constant.
// The JSON resources live in PiDay/Resources/ and are included in the app bundle
// via XcodeGen project.yml.
@MainActor
final class DefaultFeaturedNumberRepository: FeaturedNumberRepository {
    private let generator = DateStringGenerator()

    // One store per featured number, so "pi" and "pi416" can share the same digits
    // while still computing featured-day stats independently.
    private var stores: [CalendarFeaturedNumber: PiStore] = [:]

    // Cache per date+format+number to avoid recomputing summaries on navigation.
    private var cache: [String: DateLookupSummary] = [:]

    nonisolated init() {}

    func loadBundledIndexes() async throws {
        // We intentionally load sequentially on the MainActor.
        // Each PiStore.loadInBackground() performs decoding in a detached task, so
        // this does not block the UI thread for the duration of JSON parsing.
        for featured in CalendarFeaturedNumber.allCases {
            let store = self.store(for: featured)
            try await store.loadInBackground(fromResource: featured.indexResourceName)
        }
        cache.removeAll()
    }

    func indexedYearRange(for featuredNumber: CalendarFeaturedNumber) -> ClosedRange<Int>? {
        guard let meta = store(for: featuredNumber).payload?.metadata else { return nil }
        return meta.startYear...meta.endYear
    }

    func excerptRadius(for featuredNumber: CalendarFeaturedNumber) -> Int {
        store(for: featuredNumber).payload?.metadata.excerptRadius ?? 20
    }

    func stats(for featuredNumber: CalendarFeaturedNumber) -> PiStats? {
        store(for: featuredNumber).stats
    }

    func summary(for featuredNumber: CalendarFeaturedNumber, date: Date, formats: [DateFormatOption]) -> DateLookupSummary {
        guard let range = indexedYearRange(for: featuredNumber) else {
            return DateLookupSummary(
                isoDate: generator.isoDateString(for: date),
                matches: [],
                bestMatch: nil,
                source: .bundled,
                errorMessage: "Bundled index unavailable."
            )
        }

        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        guard range.contains(year) else {
            return DateLookupSummary(
                isoDate: generator.isoDateString(for: date),
                matches: [],
                bestMatch: nil,
                source: .bundled,
                errorMessage: "Outside bundled index range."
            )
        }

        let key = cacheKey(for: featuredNumber, date: date, formats: formats)
        if let cached = cache[key] { return cached }

        let result = store(for: featuredNumber).summary(for: date, formats: formats)
        cache[key] = result
        return result
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func store(for featured: CalendarFeaturedNumber) -> PiStore {
        if let existing = stores[featured] { return existing }
        let created = PiStore(featuredNumberForStats: featured)
        stores[featured] = created
        return created
    }

    private func cacheKey(for featured: CalendarFeaturedNumber, date: Date, formats: [DateFormatOption]) -> String {
        let iso = generator.isoDateString(for: date)
        let formatKey = formats.map(\.rawValue).sorted().joined(separator: ",")
        return "\(featured.rawValue)-\(iso)-\(formatKey)"
    }
}
