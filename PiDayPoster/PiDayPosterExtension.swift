import SwiftUI
import PosterKit

// WHY: The @main entry point for the Poster extension.
// It declares the available configurations to the system.
@main
struct PiDayPosterExtension: Poster {
    var body: some PosterConfiguration {
        // We use a dynamic configuration that re-generates every day at midnight.
        DynamicPosterConfiguration(
            kind: "academy.glasscode.piday.poster",
            provider: PiDayPosterProvider()
        ) { entry in
            PiDayPosterView(entry: entry)
        }
        .configurationDisplayName("Pi Day Wallpaper")
        .description("A dynamic wallpaper that shows today's position in Pi.")
    }
}

struct PiDayPosterProvider: PosterProvider {
    // Returns the entry for the current date.
    func entry(for date: Date) async -> PosterEntry {
        PosterProvider.generateEntry(for: date)
    }

    // Tells the system when to refresh.
    func refreshSchedule() -> PosterRefreshSchedule {
        .dailyAtMidnight
    }
}
