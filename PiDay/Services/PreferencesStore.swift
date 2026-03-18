import SwiftUI
import Observation
import WidgetKit

// WHY a separate PreferencesStore (not folded into AppViewModel):
// Preferences describe how the app *looks*, not how it *computes*.
// Keeping them apart means:
//   • Any view can read preferences without pulling in the full ViewModel graph
//   • The widget (future) can read font/size prefs without AppViewModel
//   • Unit-testing appearance logic doesn't require mocking the repository

@Observable
@MainActor
final class PreferencesStore {

    // MARK: - Observed properties

    var theme:     AppTheme     = .frost
    var appearanceMode: AppAppearanceMode = .system
    var fontStyle: AppFontStyle = .sfMono
    var fontWeight: AppFontWeight = .semibold
    var digitSize: DigitSize    = .medium

    // Updated by the root view via onChange(of: colorScheme) so that resolvedPalette
    // can pick the right dark/light variant when appearanceMode == .system.
    var systemColorScheme: ColorScheme = .light

    // Custom accent stored as three Double components because Color is not Codable
    // and NSKeyedArchiver is fragile across OS versions. Raw RGBA doubles are plain
    // Foundation types that round-trip through UserDefaults without any ceremony.
    // WHY not a single hex string: parsing a hex string re-introduces fragility;
    // three doubles are simpler, cheaper, and never need error handling.
    var customAccentR: Double = 0.140
    var customAccentG: Double = 0.440
    var customAccentB: Double = 0.750

    // MARK: - Derived

    // Convenience computed property so call sites write `store.customAccent`,
    // not three separate store.customAccentX reads.
    var customAccent: Color {
        get {
            Color(red: customAccentR, green: customAccentG, blue: customAccentB)
        }
        set {
            // UIColor.getRed extracts device-independent sRGB components.
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(newValue).getRed(&r, green: &g, blue: &b, alpha: &a)
            customAccentR = r
            customAccentG = g
            customAccentB = b
        }
    }

    // The effective color scheme after applying appearanceMode on top of systemColorScheme.
    // Dark-signature themes (slate, coppice, aurora, matrix) force dark rendering when
    // the user has left appearanceMode on .system, so they never accidentally render in light mode.
    var effectiveColorScheme: ColorScheme {
        if theme.isDark && appearanceMode == .system { return .dark }
        switch appearanceMode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return systemColorScheme
        }
    }

    // Resolved value for .preferredColorScheme() modifier.
    // Returns .dark for dark-signature themes under system mode; otherwise delegates
    // to the appearance mode (which may return nil to let the system decide).
    var resolvedPreferredColorScheme: ColorScheme? {
        if theme.isDark && appearanceMode == .system { return .dark }
        return appearanceMode.preferredColorScheme
    }

    // The fully-resolved palette for the active theme and effective color scheme.
    // Views read this once and get all colour tokens they need.
    var resolvedPalette: ThemePalette {
        theme.palette(customAccent: customAccent, colorScheme: effectiveColorScheme)
    }

    // MARK: - Private

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Persistence

    func load() {
        let sharedDefaults = UserDefaults(suiteName: Self.appGroupID) ?? defaults

        if let raw = sharedDefaults.string(forKey: Keys.theme) ?? defaults.string(forKey: Keys.theme),
           let t   = AppTheme(rawValue: raw)     { theme     = t }
        if let raw = sharedDefaults.string(forKey: Keys.appearanceMode) ?? defaults.string(forKey: Keys.appearanceMode),
           let mode = AppAppearanceMode(rawValue: raw) { appearanceMode = mode }
        if let raw = sharedDefaults.string(forKey: Keys.fontStyle) ?? defaults.string(forKey: Keys.fontStyle),
           let f   = AppFontStyle(rawValue: raw) { fontStyle = f }
        let storedWeight = sharedDefaults.object(forKey: Keys.fontWeight) != nil
            ? sharedDefaults.integer(forKey: Keys.fontWeight)
            : defaults.integer(forKey: Keys.fontWeight)
        if let weight = AppFontWeight(rawValue: storedWeight) {
            fontWeight = weight
        }
        if let raw = sharedDefaults.string(forKey: Keys.digitSize) ?? defaults.string(forKey: Keys.digitSize),
           let d   = DigitSize(rawValue: raw)    { digitSize = d }

        // Only overwrite the defaults if a non-zero value was previously stored.
        // (UserDefaults returns 0.0 for missing Double keys, which would be invisible black.)
        let accentSource = sharedDefaults.object(forKey: Keys.accentR) != nil ? sharedDefaults : defaults
        let r = accentSource.double(forKey: Keys.accentR)
        let g = accentSource.double(forKey: Keys.accentG)
        let b = accentSource.double(forKey: Keys.accentB)
        if r + g + b > 0 {
            customAccentR = r
            customAccentG = g
            customAccentB = b
        }
    }

    // Call after any mutation that should persist.
    // WHY explicit call (not automatic didSet): @Observable doesn't support
    // willSet/didSet on tracked properties in a way that allows calling self.
    // Explicit save() keeps the intent visible at every call site.
    func save() {
        let sharedDefaults = UserDefaults(suiteName: Self.appGroupID)

        [defaults, sharedDefaults].forEach { store in
            store?.set(theme.rawValue, forKey: Keys.theme)
            store?.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            store?.set(fontStyle.rawValue, forKey: Keys.fontStyle)
            store?.set(fontWeight.rawValue, forKey: Keys.fontWeight)
            store?.set(digitSize.rawValue, forKey: Keys.digitSize)
            store?.set(customAccentR, forKey: Keys.accentR)
            store?.set(customAccentG, forKey: Keys.accentG)
            store?.set(customAccentB, forKey: Keys.accentB)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.accessoryWidgetKind)
    }

    // MARK: - Keys

    private enum Keys {
        static let theme      = "academy.glasscode.piday.pref.theme"
        static let appearanceMode = "academy.glasscode.piday.pref.appearanceMode"
        static let fontStyle  = "academy.glasscode.piday.pref.fontStyle"
        static let fontWeight = "academy.glasscode.piday.pref.fontWeight"
        static let digitSize  = "academy.glasscode.piday.pref.digitSize"
        static let accentR    = "academy.glasscode.piday.pref.accentR"
        static let accentG    = "academy.glasscode.piday.pref.accentG"
        static let accentB    = "academy.glasscode.piday.pref.accentB"
    }

    private static let appGroupID = "group.academy.glasscode.piday"
    private static let widgetKind = "academy.glasscode.piday.widget"
    private static let accessoryWidgetKind = "academy.glasscode.piday.accessory"
}
