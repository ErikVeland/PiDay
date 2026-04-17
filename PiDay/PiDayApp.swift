import SwiftUI

@main
struct PiDayApp: App {
    // WHY: @State in App keeps both stores alive for the entire app lifecycle.
    // We inject via .environment() so any view reads them with
    //   @Environment(AppViewModel.self) or @Environment(PreferencesStore.self)
    // This is the recommended @Observable injection pattern for iOS 17+.
    @State private var viewModel = AppViewModel()
    @State private var preferences = PreferencesStore()

    @AppStorage("academy.glasscode.piday.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(viewModel)
                .environment(preferences)
                .preferredColorScheme(preferences.resolvedPreferredColorScheme)
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(
                        onDismiss: {
                            hasSeenOnboarding = true
                            showOnboarding = false
                        },
                        accentColor: preferences.resolvedPalette.accent,
                        featuredNumber: viewModel.calendarFeaturedNumber
                    )
                }
                .onOpenURL { url in
                    guard url.scheme == "piday" else { return }
                    // Expecting piday://date/YYYY-MM-DD — host == "date", path == "/YYYY-MM-DD"
                    if url.host == "date" {
                        let raw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        let f = DateFormatter()
                        f.calendar = Calendar(identifier: .gregorian)
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        f.dateFormat = "yyyy-MM-dd"
                        if let date = f.date(from: raw) {
                            viewModel.select(date)
                        }
                    }
                }
        }
    }
}
