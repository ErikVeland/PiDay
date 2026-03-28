import Foundation
import Observation

// WHY a separate ViewModel (not in AppViewModel):
// Free search is a completely different user intent — the user is typing an
// arbitrary number, not navigating dates. It has its own loading state, its own
// error state, and its own lifecycle (results reset every time you type).
// Mixing it into AppViewModel would make the state model harder to reason about.

struct FreeSearchResult: Equatable {
    let query: String
    let storedPosition: Int
    let excerpt: String
    // The short window shown in the result card
    let displayExcerpt: ExcerptDisplay

    struct ExcerptDisplay: Equatable {
        let before: String
        let highlight: String
        let after: String
    }
}

@Observable
@MainActor
final class FreeSearchViewModel {
    var query = ""
    var result: FreeSearchResult?
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var easterEggMessage: String?

    // WHY no deinit cancellation: @Observable macro-expanded properties can't be
    // accessed from nonisolated deinit in Swift 6. The [weak self] capture in the
    // task closure already ensures the ViewModel is not retained beyond its owner
    // (FreeSearchView). After deallocation, self becomes nil and the task closure
    // is a no-op at its next suspension point. A redundant API call may fire if
    // the 400ms debounce has already elapsed, but results are dropped harmlessly.
    private var searchTask: Task<Void, Never>?
    // WHY a small excerptRadius for free search: we don't know how long the
    // query will be. 60 chars gives enough context without wasting bandwidth.
    private let service = PiLiveLookupService(excerptRadius: 60)

    // Called on every keystroke from the view via .onChange.
    func queryDidChange() {
        // Filter to digits only — the API only accepts digit strings.
        let digits = query.filter(\.isNumber)
        // WHY explicit guard: assigning query = digits triggers @Observable's
        // change notification, which re-fires onChange -> queryDidChange().
        // @Observable suppresses the callback when the value is unchanged,
        // breaking the loop — but that is implicit. The guard makes the
        // termination condition obvious and safe under any future refactor.
        if query != digits { query = digits }

        searchTask?.cancel()
        result = nil
        errorMessage = nil
        hasSearched = false
        easterEggMessage = PiDelightCopy.freeSearchReaction(for: digits)

        guard digits.count >= 3 else {
            isLoading = false
            return
        }

        isLoading = true
        // WHY 400ms debounce: balances responsiveness against API rate limits.
        // Users who type fast won't fire a request for every intermediate state.
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.performSearch(digits: digits)
        }
    }

    // MARK: - Private

    private func performSearch(digits: String) async {
        do {
            hasSearched = true
            let found = try await service.searchDigits(digits)
            // WHY cancellation check after await: the network call can take several
            // seconds. If the user typed new digits while we were waiting, the task
            // was cancelled and queryDidChange already cleared state. Writing our
            // stale result here would override the cleared state — wrong outcome.
            guard !Task.isCancelled else { return }
            if let found {
                result = makeResult(
                    query: digits,
                    storedPosition: found.storedPosition,
                    fullExcerpt: found.excerpt
                )
                errorMessage = nil
                easterEggMessage = PiDelightCopy.freeSearchReaction(for: digits)
            } else {
                result = nil  // not found — view shows the "not found" state
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func makeResult(query: String, storedPosition: Int, fullExcerpt: String) -> FreeSearchResult {
        let radius = 60
        let displayRadius = 14
        let queryOffset = min(radius, storedPosition - 1)

        let display: FreeSearchResult.ExcerptDisplay = {
            guard queryOffset + query.count <= fullExcerpt.count else {
                return .init(before: "", highlight: query, after: "")
            }
            let qIdx = fullExcerpt.index(fullExcerpt.startIndex, offsetBy: queryOffset)
            let qEnd = fullExcerpt.index(qIdx, offsetBy: query.count)
            let bStart = fullExcerpt.index(qIdx, offsetBy: -min(displayRadius, queryOffset),
                                           limitedBy: fullExcerpt.startIndex) ?? fullExcerpt.startIndex
            let aEnd = fullExcerpt.index(qEnd, offsetBy: displayRadius,
                                         limitedBy: fullExcerpt.endIndex) ?? fullExcerpt.endIndex
            return .init(
                before: "…" + String(fullExcerpt[bStart..<qIdx]),
                highlight: String(fullExcerpt[qIdx..<qEnd]),
                after: String(fullExcerpt[qEnd..<aEnd]) + "…"
            )
        }()

        return FreeSearchResult(
            query: query,
            storedPosition: storedPosition,
            excerpt: fullExcerpt,
            displayExcerpt: display
        )
    }
}
