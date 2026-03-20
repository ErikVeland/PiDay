import Foundation

// WHY: Renamed from PrecomputedPiStore to PiStore — shorter, still clear.
// This class owns exactly one concern: load and query the bundled JSON index.
// It has no knowledge of live lookups or the ViewModel.

enum PiStoreError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "Missing exact-match index resource: \(name). Generate a real pi index before running the app."
        }
    }
}

final class PiStore: Sendable {
    // WHY nonisolated(unsafe): payload is mutable, which normally violates Sendable.
    //
    // Main app: DefaultPiRepository is @MainActor — all reads and the single write
    // (the result of `loadInBackground()`) happen on the main actor. No concurrent access.
    //
    // Widget: PiDayProvider.cachedStore is a `static let` whose initializer closure
    // calls `load()` synchronously and returns the fully-populated store. Swift's
    // `static let` uses dispatch_once semantics — the closure runs to completion
    // before any caller can access the result. After that point payload is only read,
    // never written. No concurrent write can occur.
    //
    // In both cases the access pattern is: one write, then many reads. nonisolated(unsafe)
    // asserts that we are managing this invariant manually. Using @unchecked Sendable at
    // the class level would be broader and mask other potential issues.
    nonisolated(unsafe) private(set) var payload: PiIndexPayload?
    private let generator = DateStringGenerator()

    // Synchronous load — useful for tests with a known URL.
    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        payload = try JSONDecoder().decode(PiIndexPayload.self, from: data)
    }

    // Async load off the main thread — the normal app startup path.
    func loadInBackground(
        fromResource resourceName: String = "pi_2026_2035_index",
        withExtension ext: String = "json",
        bundle: Bundle = .main
    ) async throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: ext) else {
            throw PiStoreError.missingResource("\(resourceName).\(ext)")
        }
        payload = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PiIndexPayload.self, from: data)
        }.value
    }

    func summary(for date: Date, formats: [DateFormatOption]) -> DateLookupSummary {
        let isoDate = generator.isoDateString(for: date)
        let queries = generator.strings(for: date, formats: formats)
        let record = payload?.dates[isoDate]

        let matches = queries.map { format, query -> PiMatchResult in
            if let match = record?.formats[format], match.query == query {
                return PiMatchResult(
                    query: match.query,
                    format: format,
                    found: true,
                    storedPosition: match.position,
                    excerpt: match.excerpt
                )
            }
            return PiMatchResult(query: query, format: format, found: false, storedPosition: nil, excerpt: nil)
        }
        .sorted(by: PiMatchResult.sortByPosition)

        let bestMatch = matches
            .compactMap { result -> BestPiMatch? in
                guard let position = result.storedPosition, let excerpt = result.excerpt else { return nil }
                return BestPiMatch(format: result.format, query: result.query, storedPosition: position, excerpt: excerpt)
            }
            .min(by: { $0.storedPosition < $1.storedPosition })

        return DateLookupSummary(
            isoDate: isoDate,
            matches: matches,
            bestMatch: bestMatch,
            source: .bundled,
            errorMessage: nil
        )
    }

}
