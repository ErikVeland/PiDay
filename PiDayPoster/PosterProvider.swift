import SwiftUI
import Foundation

// WHY: PosterProvider manages the available wallpaper configurations.
// In iOS 26, Posters can be dynamic and react to system events like date changes.
struct PosterProvider {
    // This would be the entry point for the system to discover available posters.
    // We provide a single "Pi Day" poster that updates daily.
    static func generateEntry(for date: Date) -> PosterEntry {
        let store = PiStore()
        if let url = Bundle.main.url(forResource: "pi_2026_2035_index", withExtension: "json") {
            try? store.load(from: url)
        }
        
        let preference = SearchFormatPreference.international
        let summary = store.summary(for: date, formats: preference.formats)
        let theme = AppTheme.frost // Default, can be customized via intent
        
        return PosterEntry(
            date: date,
            match: summary.bestMatch,
            palette: theme.palette()
        )
    }
}

struct PosterEntry {
    let date: Date
    let match: BestPiMatch?
    let palette: ThemePalette
}
