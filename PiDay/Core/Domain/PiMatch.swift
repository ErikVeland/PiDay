import Foundation

// WHY: All pi-search result types live here. They form the core "output" of the
// repository layer — both the ViewModel and Views depend on these shapes.

struct PiMatchResult: Identifiable, Equatable {
    let query: String
    let format: DateFormatOption
    let found: Bool
    let storedPosition: Int?
    let excerpt: String?

    var id: String { "\(format.rawValue)-\(query)" }

    static func sortByPosition(_ left: PiMatchResult, _ right: PiMatchResult) -> Bool {
        switch (left.storedPosition, right.storedPosition) {
        case let (lhs?, rhs?): return lhs < rhs
        case (_?, nil):        return true
        case (nil, _?):        return false
        case (nil, nil):       return left.format.displayName < right.format.displayName
        }
    }
}

// BestPiMatch is always a found result with a confirmed position and excerpt.
// Keeping it separate from PiMatchResult avoids Optional gymnastics at the call site.
struct BestPiMatch: Equatable {
    let format: DateFormatOption
    let query: String
    let storedPosition: Int
    let excerpt: String

    // WHY: When multiple formats match, any zero-padded format (e.g. DDMMYYYY "03052026")
    // is preferred over D/M/YYYY without leading zeros (e.g. "352026"), even if the
    // no-leading-zeros sequence appears earlier in pi. Shorter strings match more
    // frequently in any digit stream simply because there are more candidate windows;
    // users recognise a padded date string as their birthday — a bare "352026" looks
    // like a bug (leading zeros "dropped"). Only fall back to dmyNoLeadingZeros when
    // no padded format produced a match.
    static func preferringPadded(_ lhs: BestPiMatch, _ rhs: BestPiMatch) -> Bool {
        let lhsPadded = lhs.format != .dmyNoLeadingZeros
        let rhsPadded = rhs.format != .dmyNoLeadingZeros
        if lhsPadded != rhsPadded { return lhsPadded }
        return lhs.storedPosition < rhs.storedPosition
    }
}

// Where the result came from — bundled JSON or the live API.
enum LookupSource: String, Equatable {
    case bundled
    case live

    var label: String {
        switch self {
        case .bundled:
            return "Bundled"
        case .live:
            return "Live"
        }
    }
}

struct DateLookupSummary: Equatable {
    let isoDate: String
    let matches: [PiMatchResult]
    let bestMatch: BestPiMatch?
    let source: LookupSource
    let errorMessage: String?

    var foundCount: Int {
        matches.filter(\.found).count
    }
}
