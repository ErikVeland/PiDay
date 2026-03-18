import Foundation
import Observation

// WHY @Observable: the saved dates list drives UI in both DetailSheetView and
// SavedDatesView. Fine-grained observation means only the views that read `dates`
// re-render when a date is added or removed.
//
// WHY UserDefaults (not Core Data / SwiftData): users will have at most ~10 saved
// dates. Core Data adds migration risk and boilerplate. SwiftData is elegant but
// overkill here. Codable + UserDefaults is the right tool for a small flat list.
@Observable
@MainActor
final class SavedDatesStore {
    private(set) var dates: [SavedDate] = []

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }
    private let key = "academy.glasscode.piday.savedDates"

    func load() {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([SavedDate].self, from: data)
        else { return }
        dates = decoded
    }

    func upsert(_ date: SavedDate) {
        if let idx = dates.firstIndex(where: { $0.id == date.id }) {
            dates[idx] = date
        } else {
            dates.append(date)
        }
        persist()
    }

    func delete(_ date: SavedDate) {
        dates.removeAll { $0.id == date.id }
        persist()
    }

    func contains(date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        dates.contains { $0.matches(date, calendar: calendar) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(dates) else { return }
        defaults.set(data, forKey: key)
    }

    private static let appGroupID = "group.academy.glasscode.piday"
}
