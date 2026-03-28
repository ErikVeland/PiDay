import Foundation
import Observation

enum SavedDatesSortOption: String, CaseIterable, Identifiable {
    case bestPosition
    case label
    case calendarDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestPosition: return "Best Position"
        case .label: return "Label"
        case .calendarDate: return "Calendar Date"
        }
    }
}

struct RankedSavedDate: Identifiable, Equatable {
    let savedDate: SavedDate
    let rank: Int?
    let bestStoredPosition: Int?
    let bestFormat: DateFormatOption?
    let percentileLabel: String?

    var id: UUID { savedDate.id }
}

// WHY: @Observable (Swift 5.9 / iOS 17) replaces ObservableObject + @Published.
//
// The key benefit is fine-grained observation: SwiftUI only re-renders a View when
// a property that View actually *reads* changes. With @Published, any change to any
// property re-renders every observer. With @Observable, if a View only reads
// `selectedDate`, it won't re-render when `isLoading` changes.
//
// We also eliminated the SearchState struct. With ObservableObject you often wrap state
// in a struct so you can publish it as a single @Published value. With @Observable,
// each property is tracked individually — the wrapper adds indirection with no benefit.

@MainActor
@Observable
final class AppViewModel {

    // MARK: - Observed state
    // Everything below is automatically tracked by @Observable.

    // The currently selected date (drives the detail panel and canvas).
    var selectedDate: Date

    // The month displayed in the calendar sheet.
    var displayedMonth: Date

    // Result of the most recent lookup for selectedDate.
    var lookupSummary: DateLookupSummary?

    // True while the bundled index loads at startup or a live lookup is in flight.
    var isLoading = true

    // Shown in the UI when a network or file error occurs.
    var errorMessage: String?

    // How digit positions are labeled (1 = first digit, or 0 = first digit).
    var indexingConvention: IndexingConvention = .oneBased

    // Which date formats to search (international, american, iso, all).
    var searchPreference: SearchFormatPreference = .international

    // Per-cell summaries for the displayed calendar month.
    var daySummaries: [Date: DaySummary] = [:]

    // Saved dates — owned here so both DetailSheetView and SavedDatesView observe the same store.
    let savedDatesStore = SavedDatesStore()

    // Set to true when enough engagement is detected; the view reads this to trigger StoreKit.
    // WHY the view handles StoreKit: @Environment(\.requestReview) is only available in Views.
    var shouldPromptForRating = false

    // WHY version counter (not Bool): MainView uses onChange(of:) which only fires when
    // the value changes. A Bool could get "stuck" at true if two birthday selections arrive
    // back-to-back without a false transition in between. Incrementing an Int guarantees
    // each successful birthday lookup produces a unique value and therefore a distinct event.
    private(set) var birthdayConfettiVersion = 0

    // Cached notification authorization state — loaded once in load() so sheets
    // don't re-query on every open.
    var notificationAuthState: NotificationService.AuthorizationState = .notDetermined

    // MARK: - Non-observed state (doesn't need to drive UI)

    let today: Date
    private(set) var monthSection: MonthSection

    // MARK: - Private

    private let calendar: Calendar
    private let repository: any PiRepository
    private let generator = DateStringGenerator()  // WHY hoisted: avoid per-call allocation

    // WHY bounded cache: months are lightweight but accumulate without limit if the
    // user browses far back/forward. We keep the 6 most-recently-built months —
    // enough for smooth back/forward navigation without unbounded growth.
    private var monthSummaryCache: [String: [Date: DaySummary]] = [:]
    private var monthSummaryCacheKeys: [String] = []
    private let maxCachedMonths = 6

    private var lookupTask: Task<Void, Never>?
    // Set by selectBirthday(_:); consumed and cleared at the start of refreshSelection.
    private var confettiPending = false

    // Tracks unique ISO date strings navigated; resets after triggering rating prompt.
    private var distinctDatesViewed: Set<String> = []

    // WHY persisted in UserDefaults: without persistence the flag resets on every
    // cold-start, causing the review prompt to fire again after just 7 more taps.
    // StoreKit caps prompts at 3/year, but it's better not to lean on that limit.
    private static let ratingPromptKey       = "academy.glasscode.piday.hasPromptedForRating"
    private static let searchPreferenceKey   = "academy.glasscode.piday.searchPreference"
    private static let indexingConventionKey = "academy.glasscode.piday.indexingConvention"
    private static let appGroupID            = "group.academy.glasscode.piday"

    // Infer a sensible first-launch default from the device locale.
    // "Md" template → "M/d" in en_US (American) vs "d/M" in en_GB (International).
    private static func localeDefaultSearchPreference() -> SearchFormatPreference {
        let fmt = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: .current) ?? ""
        guard let mIdx = fmt.firstIndex(of: "M"), let dIdx = fmt.firstIndex(of: "d") else {
            return .all
        }
        return mIdx < dIdx ? .american : .international
    }
    private var hasPromptedForRating: Bool {
        get { UserDefaults.standard.bool(forKey: Self.ratingPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.ratingPromptKey) }
    }

    // WHY firstLaunchDate gate: 7 distinct dates can be navigated in the first
    // 60 seconds of the first launch, which is too aggressive. We require the
    // user to have had the app open for at least 2 minutes before prompting.
    // WHY TimeInterval (not Date): Date.init() is @MainActor in iOS 26 SDK,
    // causing Swift 6 isolation errors in computed properties. Storing a plain
    // Double avoids the actor-isolated initializer entirely.
    private static let firstLaunchKey = "academy.glasscode.piday.firstLaunchDate"
    private var hasBeenOpenLongEnough: Bool {
        let stored = UserDefaults.standard.double(forKey: Self.firstLaunchKey)
        if stored == 0 {
            UserDefaults.standard.set(Date.now.timeIntervalSinceReferenceDate, forKey: Self.firstLaunchKey)
            return false
        }
        return Date.now.timeIntervalSinceReferenceDate - stored >= 120  // 2 minutes
    }

    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    // MARK: - Init

    // WHY: We accept a repository parameter so tests can inject a mock.
    // In production, the default is DefaultPiRepository.
    // Explicit @MainActor keeps the initializer aligned with Swift 6 actor-isolation
    // rules in the iOS 26 toolchain.
    @MainActor
    init(
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        repository: (any PiRepository)? = nil
    ) {
        self.calendar = calendar
        self.repository = repository ?? DefaultPiRepository()
        self.today = calendar.startOfDay(for: today)

        let selectedDate = calendar.startOfDay(for: today)
        let displayedMonth = calendar.startOfMonth(for: selectedDate)

        self.selectedDate = selectedDate
        self.displayedMonth = displayedMonth
        self.monthSection = MonthSection(monthTitle: "", weekdaySymbols: calendar.orderedWeekdaySymbols, days: [])

        // Restore persisted format preference; on first launch derive from system locale.
        if let raw = sharedDefaults.string(forKey: Self.searchPreferenceKey),
           let saved = SearchFormatPreference(rawValue: raw) {
            searchPreference = saved
        } else {
            searchPreference = Self.localeDefaultSearchPreference()
        }

        // Restore persisted indexing convention (stays .oneBased if never changed).
        if let raw = sharedDefaults.string(forKey: Self.indexingConventionKey),
           let saved = IndexingConvention(rawValue: raw) {
            indexingConvention = saved
        }

        persistPreference(searchPreference.rawValue, forKey: Self.searchPreferenceKey)
        persistPreference(indexingConvention.rawValue, forKey: Self.indexingConventionKey)

        Task { await self.load() }
    }

    // MARK: - Derived properties

    var bestMatch: BestPiMatch? {
        lookupSummary?.bestMatch
    }

    var activeFormat: DateFormatOption {
        bestMatch?.format ?? searchPreference.heroFormat
    }

    var isSelectedDateInRange: Bool {
        repository.isInBundledRange(selectedDate)
    }

    var indexedYearRange: String {
        guard let range = repository.indexedYearRange else { return "" }
        return "\(range.lowerBound)–\(range.upperBound)"
    }

    var isCurrentDateSaved: Bool {
        savedDatesStore.contains(date: selectedDate, calendar: calendar)
    }

    var isDisplayedMonthInBundledRange: Bool {
        repository.isInBundledRange(displayedMonth)
    }

    // A snapshot of the current result ready to hand to ShareLink / share sheet.
    // WHY palette parameter: AppViewModel has no reference to PreferencesStore.
    // The caller (a View) already holds the resolved palette and passes it through.
    func shareableCard(palette: ThemePalette) -> ShareableCard {
        shareableCard(style: .classic, palette: palette)
    }

    var matchResults: [PiMatchResult] {
        lookupSummary?.matches ?? []
    }

    var excerptRadius: Int {
        repository.excerptRadius
    }

    var piStats: PiStats? {
        repository.piStats
    }

    // The exact digit string shown in the canvas — uses the best match query if found,
    // otherwise the hero-format query for the selected date.
    var exactQuery: String {
        if let bestMatch { return bestMatch.query }
        return generator.strings(for: selectedDate, formats: [searchPreference.heroFormat]).first?.1 ?? ""
    }

    var headerStatusText: String {
        if let errorMessage {
            return errorMessage
        }
        if let bestMatch {
            let displayed = displayedPosition(for: bestMatch.storedPosition)
            let sourcePrefix = lookupSummary?.source == .live ? "Live" : "Exact"
            return "\(sourcePrefix) \(bestMatch.format.displayName) hit at digit \(displayed)"
        }
        if !isSelectedDateInRange {
            return isLoading ? "Searching live pi lookup..." : "Searching outside bundled range (\(indexedYearRange))"
        }
        return "No exact \(searchPreference.summary) hit in the first 5 billion digits of pi"
    }

    /// Heat level of the best match for display in the result strip.
    /// Uses storedPosition (raw, before convention offset) so the heat bucket is
    /// consistent regardless of whether the user prefers 0-based or 1-based labeling.
    var resultHeatLevel: PiHeatLevel {
        guard let pos = bestMatch?.storedPosition else { return .none }
        if pos < 1_000     { return .hot }
        if pos < 100_000   { return .warm }
        if pos < 10_000_000 { return .cool }
        return .faint
    }

    var detailShareText: String {
        let dateString = Self.fullDateFormatter.string(from: selectedDate)
        // WHY isLoading guard: the share button is disabled while loading,
        // but this computed property has no corresponding gate. Without it,
        // a caller racing the loading state would read "not found" text when
        // the lookup is still in flight — inconsistent with the disabled UI.
        if isLoading {
            return "\(dateString) is still being searched…"
        }
        if let errorMessage {
            return "\(dateString) could not be searched right now. \(errorMessage)"
        }
        if let bestMatch {
            let displayed = displayedPosition(for: bestMatch.storedPosition)
            let src = lookupSummary?.source == .live ? "via live lookup" : "from the bundled index"
            return "\(dateString) appears in pi \(src) as the exact \(bestMatch.format.displayName) sequence \(bestMatch.query) at digit \(displayed) (\(indexingConvention.label))."
        }
        if !isSelectedDateInRange {
            return "\(dateString) is outside the search range (\(indexedYearRange))."
        }
        return "\(dateString) does not appear as an exact \(searchPreference.summary) sequence in the first 5 billion digits of pi."
    }

    var selectedDateFunFact: String? {
        PiDelightCopy.detailFact(for: selectedDate, bestMatch: bestMatch)
    }

    var rankedSavedDates: [RankedSavedDate] {
        rankedSavedDates(sortedBy: .bestPosition)
    }

    // MARK: - User actions

    func select(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)
        let monthDidChange = !calendar.isDate(normalized, equalTo: displayedMonth, toGranularity: .month)
        let previousSelectedDate = selectedDate
        selectedDate = normalized
        if monthDidChange {
            displayedMonth = calendar.startOfMonth(for: normalized)
        }
        // Track unique dates navigated; after 7 distinct dates AND 2 minutes of
        // total app use, prompt for a review. The time gate prevents prompting
        // brand-new users who happen to tap quickly through 7 dates in their first minute.
        if !hasPromptedForRating {
            distinctDatesViewed.insert(generator.isoDateString(for: normalized))
            if distinctDatesViewed.count >= 7 && hasBeenOpenLongEnough {
                hasPromptedForRating = true   // persisted to UserDefaults via computed setter
                shouldPromptForRating = true
            }
        }
        scheduleSelectionRefresh()
        if monthDidChange {
            refreshMonth()
        } else {
            updateSelectedDaySummaryState(from: previousSelectedDate, to: normalized)
        }
    }

    func setDisplayedMonth(to date: Date) {
        displayedMonth = calendar.startOfMonth(for: date)
        refreshMonth()
    }

    func setIndexingConvention(_ convention: IndexingConvention) {
        indexingConvention = convention
        persistPreference(convention.rawValue, forKey: Self.indexingConventionKey)
        refreshMonth()
    }

    func setSearchPreference(_ preference: SearchFormatPreference) {
        guard searchPreference != preference else { return }
        searchPreference = preference
        persistPreference(preference.rawValue, forKey: Self.searchPreferenceKey)
        clearCaches()
        scheduleSelectionRefresh()
        refreshMonth()
    }

    func jumpToToday() { select(Date()) }

    // Called by the birthday contact picker — same as select() but marks
    // the upcoming lookup as celebration-worthy so confetti fires on match.
    func selectBirthday(_ date: Date) {
        confettiPending = true
        select(date)
    }

    // Clears the current error and re-triggers the lookup for the selected date.
    // Called by the retry button in DetailSheetView when a live lookup fails.
    func retryCurrentLookup() {
        errorMessage = nil
        scheduleSelectionRefresh()
    }

    func refreshNotificationState() async {
        notificationAuthState = await NotificationService.authorizationState()
    }

    // Save or unsave the currently selected date (bookmark toggle).
    func toggleSaveCurrentDate() {
        if isCurrentDateSaved {
            deleteCurrentDate()
        } else {
            let label = Self.fullDateFormatter.string(from: selectedDate)
            savedDatesStore.upsert(SavedDate(label: label, date: selectedDate))
        }
    }

    private func deleteCurrentDate() {
        guard let existing = savedDatesStore.dates.first(where: { $0.matches(selectedDate, calendar: calendar) }) else { return }
        savedDatesStore.delete(existing)
    }

    // Called by the view after it has fired the StoreKit request review prompt.
    func acknowledgeRatingPrompt() {
        shouldPromptForRating = false
    }

    func showPreviousDay() {
        guard let d = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        select(d)
    }

    func showNextDay() {
        guard let d = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        select(d)
    }

    func showPreviousMonth() {
        guard let m = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: m)
        refreshMonth()
    }

    func showNextMonth() {
        guard let m = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: m)
        refreshMonth()
    }

    func displayedPosition(for storedPosition: Int) -> Int {
        indexingConvention.displayPosition(for: storedPosition)
    }

    func displayedPosition(for result: PiMatchResult) -> Int? {
        guard let stored = result.storedPosition else { return nil }
        return displayedPosition(for: stored)
    }

    func rankedSavedDates(sortedBy sort: SavedDatesSortOption) -> [RankedSavedDate] {
        let allPositions = repository.piStats?.bestDatePositions ?? []
        let generator = DateStringGenerator(calendar: calendar)

        let ranked = savedDatesStore.dates.map { saved -> RankedSavedDate in
            let summary = repository.bundledSummary(for: saved.date, formats: SearchFormatPreference.all.formats)
            let best = summary.bestMatch
            let percentile = PiDelightCopy.rarityLabel(for: best?.storedPosition, among: allPositions)
            return RankedSavedDate(
                savedDate: saved,
                rank: nil,
                bestStoredPosition: best?.storedPosition,
                bestFormat: best?.format,
                percentileLabel: best == nil ? nil : percentile
            )
        }

        let sorted: [RankedSavedDate] = switch sort {
        case .bestPosition:
            ranked.sorted { lhs, rhs in
                switch (lhs.bestStoredPosition, rhs.bestStoredPosition) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil):
                    return generator.isoDateString(for: lhs.savedDate.date) < generator.isoDateString(for: rhs.savedDate.date)
                }
            }
        case .label:
            ranked.sorted { $0.savedDate.label.localizedCaseInsensitiveCompare($1.savedDate.label) == .orderedAscending }
        case .calendarDate:
            ranked.sorted { generator.isoDateString(for: $0.savedDate.date) < generator.isoDateString(for: $1.savedDate.date) }
        }

        return sorted.enumerated().map { index, item in
            RankedSavedDate(
                savedDate: item.savedDate,
                rank: item.bestStoredPosition == nil ? nil : index + 1,
                bestStoredPosition: item.bestStoredPosition,
                bestFormat: item.bestFormat,
                percentileLabel: item.percentileLabel
            )
        }
    }

    func shareableCard(style: ShareCardStyle, palette: ThemePalette) -> ShareableCard {
        ShareableCard(
            style: style,
            date: selectedDate,
            bestMatch: bestMatch,
            query: exactQuery,
            format: activeFormat,
            displayedPosition: bestMatch.map { displayedPosition(for: $0.storedPosition) },
            excerptRadius: excerptRadius,
            palette: palette
        )
    }

    func compareCurrentDate(to otherDate: Date) async -> DateBattleResult {
        let leftDate = calendar.startOfDay(for: selectedDate)
        let rightDate = calendar.startOfDay(for: otherDate)

        async let leftSummary = repositorySummary(for: leftDate)
        async let rightSummary = repositorySummary(for: rightDate)

        return await compareDates(
            leftDate: leftDate,
            leftSummary: leftSummary,
            rightDate: rightDate,
            rightSummary: rightSummary
        )
    }

    func compareSelectedDate(withSavedDate savedDate: SavedDate) async -> DateBattleResult {
        await compareCurrentDate(to: savedDate.date)
    }

    func repositorySummary(for date: Date) async -> DateLookupSummary {
        await repository.summary(for: date, formats: searchPreference.formats)
    }

    func compareDates(
        leftDate: Date,
        leftSummary: DateLookupSummary,
        rightDate: Date,
        rightSummary: DateLookupSummary
    ) -> DateBattleResult {
        let positions = repository.piStats?.bestDatePositions ?? []

        let leftDisplayed = leftSummary.bestMatch.map { displayedPosition(for: $0.storedPosition) }
        let rightDisplayed = rightSummary.bestMatch.map { displayedPosition(for: $0.storedPosition) }

        let left = DateBattleContender(
            date: leftDate,
            summary: leftSummary,
            displayedPosition: leftDisplayed,
            percentileLabel: PiDelightCopy.rarityLabel(for: leftSummary.bestMatch?.storedPosition, among: positions)
        )

        let right = DateBattleContender(
            date: rightDate,
            summary: rightSummary,
            displayedPosition: rightDisplayed,
            percentileLabel: PiDelightCopy.rarityLabel(for: rightSummary.bestMatch?.storedPosition, among: positions)
        )

        let winner: DateBattleWinner
        let margin: Int?
        switch (leftDisplayed, rightDisplayed) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                winner = .tie
                margin = 0
            } else if lhs < rhs {
                winner = .left
                margin = rhs - lhs
            } else {
                winner = .right
                margin = lhs - rhs
            }
        case (_?, nil):
            winner = .left
            margin = nil
        case (nil, _?):
            winner = .right
            margin = nil
        case (nil, nil):
            winner = .tie
            margin = nil
        }

        return DateBattleResult(
            left: left,
            right: right,
            winner: winner,
            winningMargin: margin,
            verdict: PiDelightCopy.verdict(for: left, right: right, margin: margin)
        )
    }

    // MARK: - Private helpers

    private func load() async {
        isLoading = true
        do {
            try await repository.loadBundledIndex()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        savedDatesStore.load()
        // If the user has already opted in, keep the annual reminder scheduled.
        Task { await NotificationService.schedulePiDayIfAuthorized() }
        notificationAuthState = await NotificationService.authorizationState()
        clearCaches()
        scheduleSelectionRefresh()
        refreshMonth()
        isLoading = false
    }

    // WHY: We cancel any in-flight lookup before starting a new one.
    // This prevents a slow live lookup from clobbering results for a date the
    // user already moved away from.
    private func scheduleSelectionRefresh() {
        let date = selectedDate
        lookupTask?.cancel()
        lookupTask = Task { [weak self] in
            await self?.refreshSelection(for: date)
        }
    }

    private func refreshSelection(for date: Date) async {
        // WHY captured before any await: confettiPending must be read and cleared
        // synchronously so that a subsequent birthday selection (which sets it to true
        // again) is not accidentally consumed by this lookup. Capturing into a local
        // Bool then resetting the flag atomically prevents both double-fire and loss.
        let shouldCelebrate = confettiPending
        confettiPending = false

        let normalized = calendar.startOfDay(for: date)
        let isLive = !repository.isInBundledRange(normalized)

        if isLive {
            isLoading = true
            errorMessage = nil
        }

        let summary = await repository.summary(for: normalized, formats: searchPreference.formats)

        guard !Task.isCancelled, calendar.isDate(normalized, inSameDayAs: selectedDate) else { return }

        lookupSummary = summary
        errorMessage = summary.errorMessage
        // WHY unconditional: if the user navigates from a live date (which sets
        // isLoading = true) to a bundled date before the live lookup completes,
        // the live task is cancelled but isLoading stays true. The bundled task
        // must clear it regardless of whether it was the one that set it.
        isLoading = false

        if shouldCelebrate && summary.bestMatch != nil {
            birthdayConfettiVersion += 1
        }
    }

    private func refreshMonth() {
        let section = buildMonthSection(for: displayedMonth)
        monthSection = section
        daySummaries = buildSummaryMap(for: displayedMonth, section: section)
    }

    private func updateSelectedDaySummaryState(from oldDate: Date, to newDate: Date) {
        guard oldDate != newDate else { return }

        if var old = daySummaries[oldDate] {
            old = DaySummary(
                date: old.date,
                dayNumber: old.dayNumber,
                isoDate: old.isoDate,
                isSelected: false,
                isInBundledRange: old.isInBundledRange,
                bestStoredPosition: old.bestStoredPosition,
                foundFormats: old.foundFormats
            )
            daySummaries[oldDate] = old
        }

        if var new = daySummaries[newDate] {
            new = DaySummary(
                date: new.date,
                dayNumber: new.dayNumber,
                isoDate: new.isoDate,
                isSelected: true,
                isInBundledRange: new.isInBundledRange,
                bestStoredPosition: new.bestStoredPosition,
                foundFormats: new.foundFormats
            )
            daySummaries[newDate] = new
        }

        let key = monthCacheKey(for: displayedMonth)
        if monthSummaryCache[key] != nil {
            monthSummaryCache[key] = daySummaries
        }
    }

    private func buildMonthSection(for month: Date) -> MonthSection {
        Self.monthTitleFormatter.calendar = calendar
        return MonthSection(
            monthTitle: Self.monthTitleFormatter.string(from: month),
            weekdaySymbols: calendar.orderedWeekdaySymbols,
            days: calendar.monthGrid(for: month)
        )
    }

    private func buildSummaryMap(for month: Date, section: MonthSection) -> [Date: DaySummary] {
        let key = monthCacheKey(for: month)

        // Cache hit: just update the selected state — avoid full rebuild.
        if var cached = monthSummaryCache[key] {
            if let oldSelected = cached.first(where: { $0.value.isSelected })?.key, oldSelected != selectedDate {
                if let old = cached[oldSelected] {
                    cached[oldSelected] = DaySummary(
                        date: old.date, dayNumber: old.dayNumber, isoDate: old.isoDate,
                        isSelected: false, isInBundledRange: old.isInBundledRange,
                        bestStoredPosition: old.bestStoredPosition, foundFormats: old.foundFormats
                    )
                }
            }
            if let current = cached[selectedDate] {
                cached[selectedDate] = DaySummary(
                    date: current.date, dayNumber: current.dayNumber, isoDate: current.isoDate,
                    isSelected: true, isInBundledRange: current.isInBundledRange,
                    bestStoredPosition: current.bestStoredPosition, foundFormats: current.foundFormats
                )
            }
            storeSummaryCache(cached, forKey: key)
            return cached
        }

        // Cache miss: build from scratch using bundled-only lookups (no network calls).
        let summaries = Dictionary(
            uniqueKeysWithValues: section.days
                .filter(\.isInDisplayedMonth)
                .map { day -> (Date, DaySummary) in
                    let isInBundledRange = repository.isInBundledRange(day.date)
                    let result = isInBundledRange
                        ? repository.bundledSummary(for: day.date, formats: searchPreference.formats)
                        : DateLookupSummary(
                            isoDate: generator.isoDateString(for: day.date),
                            matches: [],
                            bestMatch: nil,
                            source: .live,
                            errorMessage: nil
                        )
                    return (day.date, DaySummary(
                        date: day.date,
                        dayNumber: day.dayNumber,
                        isoDate: generator.isoDateString(for: day.date),
                        isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                        isInBundledRange: isInBundledRange,
                        bestStoredPosition: result.bestMatch?.storedPosition,
                        foundFormats: result.foundCount
                    ))
                }
        )

        storeSummaryCache(summaries, forKey: key)
        return summaries
    }

    // LRU-style bounded cache write.
    // WHY 6 months: covers comfortable back/forward browsing without unbounded growth.
    private func storeSummaryCache(_ summaries: [Date: DaySummary], forKey key: String) {
        if monthSummaryCache[key] == nil {
            if monthSummaryCacheKeys.count >= maxCachedMonths {
                let evicted = monthSummaryCacheKeys.removeFirst()
                monthSummaryCache.removeValue(forKey: evicted)
            }
            monthSummaryCacheKeys.append(key)
        }
        monthSummaryCache[key] = summaries
    }

    private func monthCacheKey(for month: Date) -> String {
        // WHY generator (not new DateStringGenerator()): generator is a stored
        // property — no allocation per call.
        "\(generator.isoDateString(for: month))-\(searchPreference.rawValue)"
    }

    private func clearCaches() {
        lookupTask?.cancel()
        monthSummaryCache.removeAll()
        monthSummaryCacheKeys.removeAll()
        repository.clearCache()
    }

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    private func persistPreference(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        sharedDefaults.set(value, forKey: key)
    }
}

// MARK: - Calendar helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    var orderedWeekdaySymbols: [String] {
        let symbols = shortStandaloneWeekdaySymbols
        let firstIndex = firstWeekday - 1
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    func monthGrid(for month: Date) -> [CalendarDay] {
        let monthStart = startOfMonth(for: month)
        guard let firstDisplayedDay = date(
            byAdding: .day,
            value: -(weekdayComponent(for: monthStart) - firstWeekday + 7) % 7,
            to: monthStart
        ) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = date(byAdding: .day, value: offset, to: firstDisplayedDay) else { return nil }
            return CalendarDay(
                date: startOfDay(for: date),
                dayNumber: component(.day, from: date),
                isInDisplayedMonth: component(.month, from: date) == component(.month, from: monthStart)
            )
        }
    }

    private func weekdayComponent(for date: Date) -> Int {
        component(.weekday, from: date)
    }
}
