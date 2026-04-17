import Foundation
import Observation

@MainActor
@Observable
final class WatchAppModel {
    private static let indexingConventionKey = "academy.glasscode.piday.indexingConvention"
    private static let calendarFeaturedNumberKey = "academy.glasscode.piday.calendarFeaturedNumber"
    private static let appGroupID = "group.academy.glasscode.piday"

    var selectedDate: Date
    var lookupSummary: DateLookupSummary?
    var isLoading = false
    var errorMessage: String?
    var featuredNumber: CalendarFeaturedNumber = .pi

    private let calendar: Calendar
    private let repository: any FeaturedNumberRepository
    private let generator = DateStringGenerator()
    private let searchPreference: SearchFormatPreference = .international
    private var hasLoadedIndex = false

    init(
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        repository: (any FeaturedNumberRepository)? = nil
    ) {
        self.calendar = calendar
        self.repository = repository ?? DefaultFeaturedNumberRepository()
        self.selectedDate = calendar.startOfDay(for: today)
        if let raw = sharedDefaults.string(forKey: Self.calendarFeaturedNumberKey),
           let saved = CalendarFeaturedNumber(rawValue: raw) {
            featuredNumber = saved
        }
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
            let rarity = PiDelightCopy.rarityLabel(
                for: bestMatch.storedPosition,
                among: repository.stats(for: featuredNumber)?.bestDatePositions ?? []
            )
            return "\(bestMatch.format.displayName) at digit \(displayedPosition(for: bestMatch.storedPosition)) · \(rarity)"
        }
        return "No exact \(searchPreference.summary) hit"
    }

    var funFact: String? {
        PiDelightCopy.detailFact(for: featuredNumber, date: selectedDate, bestMatch: bestMatch)
    }

    func loadIfNeeded() async {
        guard !hasLoadedIndex else {
            await refresh()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await repository.loadBundledIndexes()
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
        let summary = repository.summary(for: featuredNumber, date: selectedDate, formats: searchPreference.formats)
        lookupSummary = summary
        errorMessage = summary.errorMessage
        isLoading = false
    }

    private func displayedPosition(for storedPosition: Int) -> Int {
        indexingConventionRawValue == "zeroBased" ? storedPosition - 1 : storedPosition
    }

    private var indexingConventionRawValue: String {
        sharedDefaults.string(forKey: Self.indexingConventionKey) ?? "oneBased"
    }

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }
}
