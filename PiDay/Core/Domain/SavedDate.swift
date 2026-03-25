import Foundation

// WHY: SavedDate is a pure value type — no logic, no dependencies.
// Keeping it in Core/Domain means both the app and (eventually) widgets
// can reference it without pulling in SwiftUI or service code.
struct SavedDate: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    private var year: Int
    private var month: Int
    private var day: Int

    var date: Date {
        get { Self.displayDate(year: year, month: month, day: day) }
        set {
            let components = Self.calendar.dateComponents([.year, .month, .day], from: newValue)
            year = components.year ?? year
            month = components.month ?? month
            day = components.day ?? day
        }
    }

    var isoDate: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init(id: UUID = UUID(), label: String, date: Date, calendar: Calendar? = nil) {
        self.id = id
        self.label = label
        let components = (calendar ?? Self.calendar).dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    func matches(_ date: Date, calendar: Calendar = SavedDate.calendar) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year == year && components.month == month && components.day == day
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case year
        case month
        case day
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)

        if
            let year = try container.decodeIfPresent(Int.self, forKey: .year),
            let month = try container.decodeIfPresent(Int.self, forKey: .month),
            let day = try container.decodeIfPresent(Int.self, forKey: .day)
        {
            self.year = year
            self.month = month
            self.day = day
        } else {
            let legacyDate = try container.decode(Date.self, forKey: .date)
            let components = Self.calendar.dateComponents([.year, .month, .day], from: legacyDate)
            self.year = components.year ?? 1970
            self.month = components.month ?? 1
            self.day = components.day ?? 1
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(day, forKey: .day)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    private static func displayDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        // This can only fail if the stored year/month/day components are invalid
        // (e.g. Feb 30). Since they are always decomposed from a real Date in init,
        // this fallback should never be reached. Using a distant-past sentinel makes
        // any bug immediately visible in the UI rather than silently showing "today".
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
