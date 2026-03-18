import XCTest
@testable import PiDay

final class PiDayCoreTests: XCTestCase {
    @MainActor
    private final class MockPiRepository: PiRepository {
        var indexedYearRange: ClosedRange<Int>? = 2026...2035
        var excerptRadius: Int = 20
        var summaryResult: DateLookupSummary

        init(summaryResult: DateLookupSummary) {
            self.summaryResult = summaryResult
        }

        func isInBundledRange(_ date: Date) -> Bool { false }
        func loadBundledIndex() async throws {}
        func summary(for date: Date, formats: [DateFormatOption]) async -> DateLookupSummary { summaryResult }
        func bundledSummary(for date: Date, formats: [DateFormatOption]) -> DateLookupSummary { summaryResult }
        func clearCache() {}
    }

    private var exactIndexURL: URL {
        get throws {
            let bundle = Bundle(for: type(of: self))
            guard let url = bundle.url(forResource: "pi_2026_2035_index", withExtension: "json") else {
                throw XCTSkip("pi_2026_2035_index.json not found in test bundle")
            }
            return url
        }
    }

    func testDateStringGeneratorProducesExpectedFormats() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(calendar: calendar, year: 2026, month: 3, day: 14)
        let date = calendar.date(from: components)!

        let results = DateStringGenerator().strings(for: date, formats: DateFormatOption.allCases)
        let map = Dictionary(uniqueKeysWithValues: results)

        XCTAssertEqual(map[.yyyymmdd], "20260314")
        XCTAssertEqual(map[.ddmmyyyy], "14032026")
        XCTAssertEqual(map[.mmddyyyy], "03142026")
        XCTAssertEqual(map[.yymmdd], "260314")
        XCTAssertEqual(map[.dmyNoLeadingZeros], "1432026")
    }

    func testIsoDateStringDoesNotSlipAcrossTimeZones() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        let date = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 3, day: 16))!

        XCTAssertEqual(DateStringGenerator().isoDateString(for: date), "2026-03-16")
    }

    func testStructuredStoreReturnsBestMatchForPiDay() throws {
        let store = PiStore()
        try store.load(from: exactIndexURL)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 3, day: 14))!
        let summary = store.summary(for: date, formats: [.ddmmyyyy])

        XCTAssertEqual(summary.isoDate, "2026-03-14")
        XCTAssertEqual(summary.bestMatch?.format, .ddmmyyyy)
        XCTAssertEqual(summary.bestMatch?.query, "14032026")
        XCTAssertEqual(summary.bestMatch?.storedPosition, 97057981)
        XCTAssertEqual(summary.foundCount, 1)
    }

    func testStructuredStoreCanSearchAmericanFormat() throws {
        let store = PiStore()
        try store.load(from: exactIndexURL)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 3, day: 14))!
        let summary = store.summary(for: date, formats: [.mmddyyyy])

        XCTAssertEqual(summary.isoDate, "2026-03-14")
        XCTAssertEqual(summary.bestMatch?.format, .mmddyyyy)
        XCTAssertEqual(summary.bestMatch?.query, "03142026")
        XCTAssertEqual(summary.foundCount, 1)
    }

    func testExactIndexContainsEveryDateIn2026() throws {
        let store = PiStore()
        try store.load(from: exactIndexURL)

        let payload = try XCTUnwrap(store.payload)
        XCTAssertEqual(payload.metadata.startYear, 2026)
        XCTAssertEqual(payload.metadata.endYear, 2035)
        XCTAssertGreaterThanOrEqual(payload.dates.count, 365)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 1, day: 1))!
        for offset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let isoDate = DateStringGenerator().isoDateString(for: date)
            XCTAssertNotNil(payload.dates[isoDate], "Missing \(isoDate) from 2026 exact-match dataset")
        }
    }

    func testEveryDateContainsAllBundledFormats() throws {
        let store = PiStore()
        try store.load(from: exactIndexURL)

        let payload = try XCTUnwrap(store.payload)
        for (isoDate, record) in payload.dates {
            XCTAssertNotNil(record.formats[.ddmmyyyy], "Missing DDMMYYYY match for \(isoDate)")
            XCTAssertNotNil(record.formats[.mmddyyyy], "Missing MMDDYYYY match for \(isoDate)")
            XCTAssertNotNil(record.formats[.yyyymmdd], "Missing YYYYMMDD match for \(isoDate)")
        }
    }

    func testStructuredStoreCanSearchIsoFormat() throws {
        let store = PiStore()
        try store.load(from: exactIndexURL)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 3, day: 14))!
        let summary = store.summary(for: date, formats: [.yyyymmdd])

        XCTAssertEqual(summary.isoDate, "2026-03-14")
        XCTAssertEqual(summary.bestMatch?.format, .yyyymmdd)
        XCTAssertEqual(summary.bestMatch?.query, "20260314")
        XCTAssertEqual(summary.foundCount, 1)
    }

    func testIndexingConventionOffsetsDisplay() {
        XCTAssertEqual(IndexingConvention.oneBased.displayPosition(for: 314), 314)
        XCTAssertEqual(IndexingConvention.zeroBased.displayPosition(for: 314), 313)
    }

    func testSavedDateMatchesAcrossTimeZones() {
        var brisbane = Calendar(identifier: .gregorian)
        brisbane.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        let original = brisbane.date(from: DateComponents(calendar: brisbane, year: 2026, month: 3, day: 14, hour: 9))!

        let saved = SavedDate(label: "Pi Day", date: original)

        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let sameCalendarDayElsewhere = losAngeles.date(from: DateComponents(calendar: losAngeles, year: 2026, month: 3, day: 14, hour: 9))!

        XCTAssertTrue(saved.matches(sameCalendarDayElsewhere, calendar: losAngeles))
        XCTAssertEqual(saved.isoDate, "2026-03-14")
    }

    func testSavedDateDecodesLegacyAbsoluteDatePayload() throws {
        let legacyJSON = """
        {
          "id": "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
          "label": "Birthday",
          "date": 763603200
        }
        """

        let decoded = try JSONDecoder().decode(SavedDate.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.label, "Birthday")
        XCTAssertEqual(decoded.isoDate, "1994-03-14")
    }

    @MainActor
    func testAppViewModelSurfacesLiveLookupErrors() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(calendar: calendar, year: 2042, month: 3, day: 14))!

        let summary = DateLookupSummary(
            isoDate: "2042-03-14",
            matches: [PiMatchResult(query: "14032042", format: .ddmmyyyy, found: false, storedPosition: nil, excerpt: nil)],
            bestMatch: nil,
            source: .live,
            errorMessage: "Live pi lookup returned an unexpected response."
        )

        let repository = MockPiRepository(summaryResult: summary)
        let viewModel = AppViewModel(today: date, calendar: calendar, repository: repository)

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.errorMessage, "Live pi lookup returned an unexpected response.")
        XCTAssertEqual(viewModel.headerStatusText, "Live pi lookup returned an unexpected response.")
        XCTAssertEqual(
            viewModel.detailShareText,
            "Friday, 14 March 2042 could not be searched right now. Live pi lookup returned an unexpected response."
        )
    }
}
