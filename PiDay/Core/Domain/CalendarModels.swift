import Foundation

// WHY: Calendar-specific domain types are grouped here. They depend on IndexingConvention
// but have no SwiftUI dependency — making them testable in isolation.

struct CalendarDay: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool

    var id: Date { date }
}

struct MonthSection: Equatable {
    let monthTitle: String
    let weekdaySymbols: [String]
    let days: [CalendarDay]
}

// DaySummary is the ViewModel-level type for one calendar cell.
// It combines CalendarDay with pi-hit metadata so the View is pure display logic.
struct DaySummary: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let isoDate: String
    let isSelected: Bool
    let isInBundledRange: Bool
    let bestStoredPosition: Int?
    let foundFormats: Int

    var id: Date { date }
    var isFound: Bool { bestStoredPosition != nil }

    func displayedBestPosition(using convention: IndexingConvention) -> Int? {
        guard let bestStoredPosition else { return nil }
        return convention.displayPosition(for: bestStoredPosition)
    }

    func heatLevel(using convention: IndexingConvention) -> PiHeatLevel {
        guard let position = displayedBestPosition(using: convention) else {
            return .none
        }
        switch position {
        case ..<1_000:
            return .hot
        case ..<100_000:
            return .warm
        case ..<10_000_000:
            return .cool
        default:
            return .faint
        }
    }
}

enum PiHeatLevel {
    case none
    case faint
    case cool
    case warm
    case hot
}
