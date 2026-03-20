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
