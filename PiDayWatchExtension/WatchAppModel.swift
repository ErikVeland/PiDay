import Foundation
import Observation

@MainActor
@Observable
final class WatchAppModel {
    var selectedDate: Date
    var lookupSummary: DateLookupSummary?
    var isLoading = false
    var errorMessage: String?

    private let calendar: Calendar
    private let repository: any PiRepository
    private let generator = DateStringGenerator()
    private let searchPreference: SearchFormatPreference = .international
    private var hasLoadedIndex = false

    init(
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        repository: (any PiRepository)? = nil
    ) {
        self.calendar = calendar
        self.repository = repository ?? DefaultPiRepository()
        self.selectedDate = calendar.startOfDay(for: today)
    }

    var bestMatch: BestPiMatch? {
        lookupSummary?.bestMatch
    }

    var displayedDate: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    var primaryQuery: String {
        if let bestMatch {
            return bestMatch.query
        }
        return generator.strings(for: selectedDate, formats: [searchPreference.heroFormat]).first?.1 ?? ""
    }

    var primaryFormat: DateFormatOption {
        bestMatch?.format ?? searchPreference.heroFormat
    }

    var statusText: String {
        if let errorMessage {
            return errorMessage
        }
        if let bestMatch {
            return "\(bestMatch.format.displayName) at digit \(bestMatch.storedPosition)"
        }
        return "No exact \(searchPreference.summary) hit"
    }

    func loadIfNeeded() async {
        guard !hasLoadedIndex else {
            await refresh()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await repository.loadBundledIndex()
            hasLoadedIndex = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            lookupSummary = nil
            isLoading = false
        }
    }

    func step(by days: Int) {
        guard let nextDate = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = calendar.startOfDay(for: nextDate)
        Task { await refresh() }
    }

    func jumpToToday() {
        selectedDate = calendar.startOfDay(for: Date())
        Task { await refresh() }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        let summary = await repository.summary(for: selectedDate, formats: searchPreference.formats)
        lookupSummary = summary
        errorMessage = summary.errorMessage
        isLoading = false
    }
}
