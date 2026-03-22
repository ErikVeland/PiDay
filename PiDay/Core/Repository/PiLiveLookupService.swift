import Foundation

// WHY: Live lookup is isolated here so it can evolve independently.
// If the external API changes its response format, only this file changes.
// It's not a repository itself — it's a data source used by DefaultPiRepository.

enum PiLiveLookupError: LocalizedError {
    case invalidResponse
    case queryMismatch

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Live pi lookup returned an unexpected response."
        case .queryMismatch:
            return "Live pi lookup returned digits that did not match the requested date."
        }
    }
}

// WHY @unchecked Sendable: all stored properties are `let` and themselves Sendable
// (URLSession, Int, DateStringGenerator). Swift 6 cannot infer Sendable for classes
// automatically, so we assert it explicitly. The class has no mutable state.
final class PiLiveLookupService: @unchecked Sendable {
    private struct LookupResponse: Decodable {
        let resultStringIdx: Int
        let numResults: Int
    }

    private struct DigitsResponse: Decodable {
        let content: String
    }

    private let generator = DateStringGenerator()
    private let session: URLSession
    private let excerptRadius: Int

    init(session: URLSession? = nil, excerptRadius: Int = 496) {
        self.excerptRadius = excerptRadius
        // WHY a short per-request timeout: the default URLSession timeout is 60 s.
        // A poor connection would hold the user on a spinner for a full minute.
        // 12 s per request is generous for a simple JSON API call.
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest  = 12
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    func summary(for date: Date, formats: [DateFormatOption]) async throws -> DateLookupSummary {
        let isoDate = generator.isoDateString(for: date)
        let queries  = generator.strings(for: date, formats: formats)

        // WHY withThrowingTaskGroup: firing all format lookups in parallel cuts
        // worst-case latency from O(n * RTT) to O(1 * RTT). With SearchFormatPreference.all
        // that shrinks five sequential round-trips down to a single parallel fan-out.
        var matches: [PiMatchResult] = []
        matches.reserveCapacity(queries.count)

        try await withThrowingTaskGroup(of: PiMatchResult.self) { group in
            for (format, query) in queries {
                group.addTask {
                    if let match = try await self.lookup(query: query, format: format) {
                        return match
                    }
                    return PiMatchResult(query: query, format: format, found: false, storedPosition: nil, excerpt: nil)
                }
            }
            for try await match in group {
                matches.append(match)
            }
        }

        matches.sort(by: PiMatchResult.sortByPosition)

        let bestMatch = matches
            .compactMap { result -> BestPiMatch? in
                guard let position = result.storedPosition, let excerpt = result.excerpt else { return nil }
                return BestPiMatch(format: result.format, query: result.query, storedPosition: position, excerpt: excerpt)
            }
            .min(by: BestPiMatch.preferringPadded)

        return DateLookupSummary(
            isoDate: isoDate,
            matches: matches,
            bestMatch: bestMatch,
            source: .live,
            errorMessage: nil
        )
    }

    // Searches for an arbitrary digit sequence in pi (not date-specific).
    // Used by FreeSearchViewModel. Returns nil if the sequence is not found.
    func searchDigits(_ digits: String) async throws -> (storedPosition: Int, excerpt: String)? {
        // We reuse the existing lookup helper. The format parameter doesn't affect
        // the API call — it's only metadata on the returned PiMatchResult.
        guard let result = try await lookup(query: digits, format: .ddmmyyyy) else { return nil }
        guard let position = result.storedPosition, let excerpt = result.excerpt else { return nil }
        return (storedPosition: position, excerpt: excerpt)
    }

    private func lookup(query: String, format: DateFormatOption) async throws -> PiMatchResult? {
        let params = [
            URLQueryItem(name: "namedDigits", value: "pi"),
            URLQueryItem(name: "find", value: query),
            URLQueryItem(name: "resultId", value: "0")
        ]
        var components = URLComponents(string: "https://v2.api.pisearch.joshkeegan.co.uk/api/v1/Lookup")
        components?.queryItems = params
        guard let url = components?.url else { throw PiLiveLookupError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PiLiveLookupError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard decoded.numResults > 0 else { return nil }

        let storedPosition = decoded.resultStringIdx + 1
        let excerpt = try await fetchExcerpt(position: storedPosition, query: query)

        return PiMatchResult(query: query, format: format, found: true, storedPosition: storedPosition, excerpt: excerpt)
    }

    private func fetchExcerpt(position: Int, query: String) async throws -> String {
        let start = max(1, position - excerptRadius)
        var components = URLComponents(string: "https://api.pi.delivery/v1/pi")
        components?.queryItems = [
            URLQueryItem(name: "start", value: "\(start)"),
            URLQueryItem(name: "numberOfDigits", value: "\(query.count + excerptRadius * 2)")
        ]
        guard let url = components?.url else { throw PiLiveLookupError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PiLiveLookupError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(DigitsResponse.self, from: data)
        let offset = min(excerptRadius, position - 1)
        guard offset < decoded.content.count,
              let startIdx = decoded.content.index(
                  decoded.content.startIndex,
                  offsetBy: offset,
                  limitedBy: decoded.content.endIndex
              ),
              decoded.content[startIdx...].hasPrefix(query) else {
            throw PiLiveLookupError.queryMismatch
        }

        return decoded.content
    }

}
