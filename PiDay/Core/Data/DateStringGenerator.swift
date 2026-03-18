import Foundation

// WHY: Generating the query strings (e.g. "14032026") from a Date is a pure
// data-transformation function. It belongs in Data, not in the ViewModel or Repository,
// because both the repository AND the live lookup service need it.
// Keeping it here avoids duplication.
struct DateStringGenerator {
    private let calendar = Calendar(identifier: .gregorian)

    // Returns (format, queryString) pairs for all requested formats.
    // e.g. for March 14 2026, .ddmmyyyy → ("14032026")
    func strings(for date: Date, formats: [DateFormatOption]) -> [(DateFormatOption, String)] {
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return []
        }

        let yyyy = String(format: "%04d", year)
        let yy = String(format: "%02d", year % 100)
        let mm = String(format: "%02d", month)
        let dd = String(format: "%02d", day)

        return formats.map { format in
            switch format {
            case .yyyymmdd:
                return (format, "\(yyyy)\(mm)\(dd)")
            case .ddmmyyyy:
                return (format, "\(dd)\(mm)\(yyyy)")
            case .mmddyyyy:
                return (format, "\(mm)\(dd)\(yyyy)")
            case .yymmdd:
                return (format, "\(yy)\(mm)\(dd)")
            case .dmyNoLeadingZeros:
                return (format, "\(day)\(month)\(year)")
            }
        }
    }

    // Canonical ISO string used as dictionary keys in the index and caches.
    func isoDateString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
