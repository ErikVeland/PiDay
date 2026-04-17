import Foundation

// WHY: The calendar can render multiple digit-heat-map indexes (π, τ, e, φ, Planck).
// Keeping the metadata here gives the ViewModel and Views one shared source of truth
// for titles, date mapping, resource names, and explanatory copy.
enum CalendarFeaturedNumber: String, CaseIterable, Identifiable {
    case pi
    case pi416
    case tau
    case euler
    case goldenRatio
    case planck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pi: return "Pi"
        case .pi416: return "Pi (4.16)"
        case .tau: return "Tau"
        case .euler: return "e"
        case .goldenRatio: return "Phi"
        case .planck: return "Planck"
        }
    }

    var shortLabel: String {
        switch self {
        case .pi: return "3.14"
        case .pi416: return "4.16"
        case .tau: return "6.28"
        case .euler: return "2.71"
        case .goldenRatio: return "1.61"
        case .planck: return "4.14"
        }
    }

    var logoSymbol: String {
        switch self {
        case .pi, .pi416:
            return "π"
        case .tau:
            return "τ"
        case .euler:
            return "e"
        case .goldenRatio:
            return "φ"
        case .planck:
            return "h"
        }
    }

    var decimalPreview: String {
        switch self {
        case .pi:
            return "3.14159..."
        case .pi416:
            return "4.16"
        case .tau:
            return "6.28318..."
        case .euler:
            return "2.71828..."
        case .goldenRatio:
            return "1.61803..."
        case .planck:
            return "4.13567... × 10⁻¹⁵"
        }
    }

    var heroCopy: String {
        switch self {
        case .pi:
            return "Choose a day to see how early it shows up in the bundled digits of π."
        case .pi416:
            return "Choose a day to see how early it shows up in the bundled digits of π. (Pi Day, but for the 3.1416 crowd.)"
        case .tau:
            return "Choose a day to see how early it shows up in the bundled digits of τ. Tau Day is June 28 (6.28)."
        case .euler:
            return "Choose a day to see how early it shows up in the bundled digits of e. (A nod to 2.71828...)"
        case .goldenRatio:
            return "Choose a day to see how early it shows up in the bundled digits of φ. (A nod to 1.61803...)"
        case .planck:
            return "Choose a day to see how early it shows up in the bundled digits of the Planck constant (h, in eV·s)."
        }
    }

    var badgeTitle: String {
        "Heat Map"
    }

    var badgeValue: String {
        "Exact \(heatMapSymbol) hits"
    }

    var observedDayLabel: String {
        switch self {
        case .pi: return "March 14"
        case .pi416: return "April 16"
        case .tau: return "June 28"
        case .euler: return "February 7"
        case .goldenRatio: return "January 6"
        case .planck: return "April 14"
        }
    }

    var legendText: String {
        switch self {
        case .pi, .pi416:
            return "Based on earliest position in the bundled π digit index."
        case .tau:
            return "Based on earliest position in the bundled τ digit index."
        case .euler:
            return "Based on earliest position in the bundled e digit index."
        case .goldenRatio:
            return "Based on earliest position in the bundled φ digit index."
        case .planck:
            return "Based on earliest position in the bundled Planck-constant digit index."
        }
    }

    var accessibilityHighlightLabel: String {
        switch self {
        case .pi:
            return "classic Pi Day"
        case .pi416:
            return "alternate Pi Day"
        case .tau:
            return "Tau Day"
        case .euler:
            return "Euler's number day"
        case .goldenRatio:
            return "golden ratio day"
        case .planck:
            return "World Quantum Day"
        }
    }

    var usesHeatMap: Bool {
        // NOTE: Whether the heat map is *visible* is determined by whether the
        // corresponding index data is bundled + loaded at runtime.
        true
    }

    // The bundled JSON index file name (without extension) for this constant.
    //
    // pi416 intentionally reuses the pi index — only the celebration framing differs.
    var indexResourceName: String {
        switch self {
        case .pi, .pi416:
            return "pi_2026_2035_index"
        case .tau:
            return "tau_2026_2035_index"
        case .euler:
            return "e_2026_2035_index"
        case .goldenRatio:
            return "phi_2026_2035_index"
        case .planck:
            return "planck_2026_2035_index"
        }
    }

    // Short label for UI copy like "Earlier in …".
    var heatMapSymbol: String {
        switch self {
        case .pi, .pi416:
            return "π"
        case .tau:
            return "τ"
        case .euler:
            return "e"
        case .goldenRatio:
            return "φ"
        case .planck:
            return "h"
        }
    }

    func highlightDate(inYear year: Int, calendar: Calendar) -> Date? {
        let components: DateComponents
        switch self {
        case .pi:
            components = DateComponents(year: year, month: 3, day: 14)
        case .pi416:
            components = DateComponents(year: year, month: 4, day: 16)
        case .tau:
            components = DateComponents(year: year, month: 6, day: 28)
        case .euler:
            components = DateComponents(year: year, month: 2, day: 7)
        case .goldenRatio:
            components = DateComponents(year: year, month: 1, day: 6)
        case .planck:
            components = DateComponents(year: year, month: 4, day: 14)
        }
        return calendar.date(from: components)
    }

    var highlightMonth: Int {
        switch self {
        case .pi: return 3
        case .pi416: return 4
        case .tau: return 6
        case .euler: return 2
        case .goldenRatio: return 1
        case .planck: return 4
        }
    }

    var highlightDay: Int {
        switch self {
        case .pi: return 14
        case .pi416: return 16
        case .tau: return 28
        case .euler: return 7
        case .goldenRatio: return 6
        case .planck: return 14
        }
    }

    func highlights(_ date: Date, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: date)
        guard let highlightDate = highlightDate(inYear: year, calendar: calendar) else { return false }
        return calendar.isDate(date, inSameDayAs: highlightDate)
    }
}
