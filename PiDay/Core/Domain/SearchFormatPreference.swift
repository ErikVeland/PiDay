import Foundation

// WHY: This enum maps a user-facing preference ("I use DD/MM") to the concrete
// DateFormatOptions the repository should search. Domain-only — no SwiftUI import needed.
enum SearchFormatPreference: String, CaseIterable, Identifiable {
    case international
    case american
    case iso8601
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .international:
            return "DD/MM"
        case .american:
            return "MM/DD"
        case .iso8601:
            return "ISO"
        case .all:
            return "All"
        }
    }

    var title: String {
        switch self {
        case .international:
            return "International"
        case .american:
            return "American"
        case .iso8601:
            return "ISO 8601"
        case .all:
            return "Indexed Formats"
        }
    }

    var formats: [DateFormatOption] {
        switch self {
        case .international:
            // WHY both: DDMMYYYY and D/M/YYYY are the same date order — one with
            // and one without leading zeros. Both are correct international forms,
            // and a date that isn't found in DDMMYYYY may still appear in D/M/YYYY.
            return [.ddmmyyyy, .dmyNoLeadingZeros]
        case .american:
            return [.mmddyyyy]
        case .iso8601:
            return [.yyyymmdd]
        case .all:
            // WHY all five: "Indexed Formats" means every format in the bundled index.
            // Previously only three were searched, meaning users could be told "not found"
            // when their date existed in YYMMDD or D/M/YYYY form.
            return [.ddmmyyyy, .dmyNoLeadingZeros, .mmddyyyy, .yyyymmdd, .yymmdd]
        }
    }

    // The single "hero" format shown prominently when no match is found.
    var heroFormat: DateFormatOption {
        switch self {
        case .international, .all:
            return .ddmmyyyy
        case .american:
            return .mmddyyyy
        case .iso8601:
            return .yyyymmdd
        }
    }

    // Short label used in "No exact X hit" messages.
    var summary: String {
        switch self {
        case .international:
            return "DDMMYYYY or D/M/YYYY"
        case .american:
            return "MMDDYYYY"
        case .iso8601:
            return "YYYYMMDD"
        case .all:
            return "any indexed format"
        }
    }
}
