import Foundation

// WHY: Isolating each domain type in its own file keeps the codebase navigable.
// When a type grows (new cases, new computed properties) it has its own space.
enum DateFormatOption: String, CaseIterable, Identifiable, Codable {
    case yyyymmdd
    case ddmmyyyy
    case mmddyyyy
    case yymmdd
    case dmyNoLeadingZeros

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yyyymmdd:
            return "YYYYMMDD"
        case .ddmmyyyy:
            return "DDMMYYYY"
        case .mmddyyyy:
            return "MMDDYYYY"
        case .yymmdd:
            return "YYMMDD"
        case .dmyNoLeadingZeros:
            return "D/M/YYYY"
        }
    }

    var description: String {
        switch self {
        case .yyyymmdd:
            return "Canonical ISO-style calendar order."
        case .ddmmyyyy:
            return "Day-first format common outside the US."
        case .mmddyyyy:
            return "Month-first format common in the US."
        case .yymmdd:
            return "Compact six-digit version."
        case .dmyNoLeadingZeros:
            return "Digits only, no leading zeros."
        }
    }

    // WHY: Splitting a query string into day/month/year segments belongs on the
    // format type itself — both the canvas view and the widget use colored text,
    // and the split logic differs per format. Centralizing it here avoids duplication.
    func queryParts(from query: String) -> (day: String, month: String, year: String) {
        switch self {
        case .yyyymmdd:
            guard query.count >= 8 else { return ("", "", query) }
            return (String(query.dropFirst(6).prefix(2)),   // day
                    String(query.dropFirst(4).prefix(2)),   // month
                    String(query.prefix(4)))                // year
        case .mmddyyyy:
            guard query.count >= 8 else { return (query, "", "") }
            return (String(query.dropFirst(2).prefix(2)),   // day
                    String(query.prefix(2)),                // month
                    String(query.dropFirst(4)))             // year
        case .ddmmyyyy:
            guard query.count >= 8 else { return (query, "", "") }
            return (String(query.prefix(2)),                // day
                    String(query.dropFirst(2).prefix(2)),   // month
                    String(query.dropFirst(4)))             // year
        case .yymmdd:
            guard query.count >= 6 else { return ("", "", query) }
            return (String(query.dropFirst(4).prefix(2)),   // day
                    String(query.dropFirst(2).prefix(2)),   // month
                    String(query.prefix(2)))                // year (YY)
        case .dmyNoLeadingZeros:
            guard query.count >= 5 else { return (query, "", "") }
            let yearPart = String(query.suffix(4))
            let dayMonth = String(query.dropLast(4))
            let splitIndex = dayMonth.index(dayMonth.startIndex, offsetBy: max(1, dayMonth.count / 2))
            return (String(dayMonth[..<splitIndex]),        // day
                    String(dayMonth[splitIndex...]),        // month
                    yearPart)                               // year
        }
    }
}
