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
    //
    // WHY date parameter: for D/M/YYYY the day and month can each be 1 or 2 digits.
    // Without the original date, splitting "148" is ambiguous — it could be
    // day=1 month=48 or day=14 month=8. Passing the date resolves this unambiguously
    // using the actual day component's digit count. All other formats have fixed-width
    // fields, so they ignore the date parameter.
    func queryParts(
        from query: String,
        date: Date? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> (day: String, month: String, year: String) {
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
            // Determine day digit count: single-digit days (1–9) produce 1 char,
            // double-digit days (10–31) produce 2 chars. Use the actual date when
            // available; fall back to a conservative 1-char day for unknown dates.
            let dayLen: Int
            if let date {
                let day = calendar.component(.day, from: date)
                dayLen = day < 10 ? 1 : 2
            } else {
                dayLen = 1
            }
            let clampedLen = max(1, min(dayLen, dayMonth.count - 1))
            let splitIndex = dayMonth.index(dayMonth.startIndex, offsetBy: clampedLen)
            return (String(dayMonth[..<splitIndex]),        // day
                    String(dayMonth[splitIndex...]),        // month
                    yearPart)                               // year
        }
    }
}
