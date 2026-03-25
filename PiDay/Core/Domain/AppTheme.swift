import SwiftUI

// WHY ThemePalette is a struct (not an enum namespace like PiPalette):
// The theme-picker swatch needs to instantiate every palette simultaneously —
// one per swatch tile — so they can sit side-by-side in a HStack.
// A static-member enum can only describe one palette at a time.
// The struct is a plain bag of Color tokens; no logic lives here.
struct ThemePalette {
    // Surfaces
    let background: Color      // page / root background
    let surface: Color         // card fill
    let border: Color          // card stroke

    // Text
    let ink: Color             // primary labels
    let mutedInk: Color        // secondary labels

    // Brand
    let accent: Color          // buttons, links, active indicators

    // Digit segment colours — shown in the pi canvas and all previews
    // WHY three independent colours: DD·MM·YYYY segments are the app's
    // signature visual. Giving each segment its own colour lets users
    // instantly parse day / month / year at a glance.
    let day: Color
    let month: Color
    let year: Color

    // Calendar heat-map fills — theme-aware so dark themes look correct.
    // WHY in ThemePalette and not PiPalette: the pastel blues and ambers
    // of the original static values look out of place on dark backgrounds.
    let heatNone: Color
    let heatFaint: Color
    let heatCool: Color
    let heatWarm: Color
    let heatHot: Color
    let heatOutOfMonth: Color
    let heatOutOfMonthForeground: Color
}

extension ThemePalette {
    func panePrimaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.label) : ink
    }

    func paneSecondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.secondaryLabel) : (ink.opacity(0.82) as Color)
    }

    func paneTertiaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.tertiaryLabel) : (ink.opacity(0.68) as Color)
    }

    func paneSurfaceFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(UIColor.secondarySystemGroupedBackground)
            : (surface.opacity(0.94) as Color)
    }

    func paneBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? (Color(UIColor.separator).opacity(0.72) as Color)
            : (border.opacity(0.95) as Color)
    }
}

// MARK: - Font Style

// WHY monospaced-only: the app displays a wall of digits — monospaced type
// keeps every character the same width so the grid is visually stable.
// rawValue "mono" retained for sfMono so existing saved preferences migrate cleanly.
enum AppFontStyle: String, CaseIterable, Identifiable, Codable {
    case sfMono   = "mono"     // SF Mono         — clean, neutral, Apple-native
    case rounded  = "rounded"  // SF Mono Rounded  — soft, friendly, still monospaced
    case courier  = "courier"  // Courier New      — classic typewriter warmth
    case menlo    = "menlo"    // Menlo            — terminal / developer aesthetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sfMono:   return "SF Mono"
        case .rounded:  return "Rounded"
        case .courier:  return "Courier"
        case .menlo:    return "Menlo"
        }
    }

    // WHY explicit bold-variant names for Courier / Menlo: Font.Weight modifiers on
    // Font.custom attempt to synthesise weights the font family doesn't have, producing
    // inconsistent results. Using the PostScript name of the real bold variant is reliable.
    //
    // WHY UIFontDescriptor.withDesign(.rounded) for .rounded: SwiftUI has no combined
    // "monospaced + rounded" design selector. Applying .rounded to SF Mono's descriptor
    // accesses the SF Mono Rounded variant that ships in the San Francisco family on
    // iOS 15+. Falls back to plain SF Mono if the system doesn't provide the variant.
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font(uiFont(size: size, weight: weight))
    }

    func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> UIFont {
        switch self {
        case .sfMono:
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight.uiFontWeight)

        case .rounded:
            let uiWeight = weight.uiFontWeight
            let base = UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight)
            if let desc = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: desc, size: size)
            }
            return base

        case .courier:
            let isBold = weight == .semibold || weight == .bold
                      || weight == .heavy   || weight == .black
            return UIFont(name: isBold ? "CourierNewPS-BoldMT" : "CourierNewPSMT", size: size)
                ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight.uiFontWeight)

        case .menlo:
            let isBold = weight == .semibold || weight == .bold
                      || weight == .heavy   || weight == .black
            return UIFont(name: isBold ? "Menlo-Bold" : "Menlo-Regular", size: size)
                ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight.uiFontWeight)
        }
    }
}

enum AppFontWeight: Int, CaseIterable, Identifiable, Codable {
    case ultraLight = 0
    case thin = 1
    case light = 2
    case regular = 3
    case medium = 4
    case semibold = 5
    case bold = 6
    case heavy = 7
    case black = 8

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .ultraLight: return "UltraLight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    static func fromSliderValue(_ value: Double) -> AppFontWeight {
        AppFontWeight(rawValue: Int(value.rounded())) ?? .regular
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// Maps SwiftUI Font.Weight → UIFont.Weight for UIFont API calls.
private extension Font.Weight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        default:          return .regular
        }
    }
}

// MARK: - Digit Size

// Three named sizes keep the API stable across future canvas refactors.
// The actual pt values live here — changing .medium from 30 → 32 is a
// one-line edit, not a grep across view files.
enum DigitSize: String, CaseIterable, Identifiable, Codable {
    case small, medium, large, xl, xxl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return "S"
        case .medium: return "M"
        case .large:  return "L"
        case .xl:     return "XL"
        case .xxl:    return "XXL"
        }
    }

    // Font size used in PiCanvasView and the live preview card
    var canvasFontSize: CGFloat {
        switch self {
        case .small:  return 22
        case .medium: return 30
        case .large:  return 40
        case .xl:     return 52
        case .xxl:    return 66
        }
    }

    // Slightly smaller font for the preview card so all sizes fit comfortably
    var previewFontSize: CGFloat { canvasFontSize * 0.85 }
}

// MARK: - Theme

// WHY presets + custom:
// • Frost   — the existing cool blue-grey palette; zero visual change on first launch
// • Slate   — deep navy; popular "developer dark" aesthetic
// • Coppice — forest green; earthy, nature-inspired
// • Ember   — warm terracotta; inviting and warm
// • Aurora  — electric teal on near-black; bold, high-contrast
// • Matrix  — phosphor green-on-black with CRT-inspired glow
// • Custom  — user's own accent on adaptive system surfaces; respects system dark mode
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case frost, slate, coppice, ember, aurora, matrix, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frost:   return "Frost"
        case .slate:   return "Slate"
        case .coppice: return "Coppice"
        case .ember:   return "Ember"
        case .aurora:  return "Aurora"
        case .matrix:  return "Matrix"
        case .custom:  return "Custom"
        }
    }

    // The "signature" color scheme for this theme — used by swatches to pick the
    // representative palette and compute shadow intensity. Independent of the user's
    // chosen AppAppearanceMode, which can override this for the live canvas.
    var defaultColorScheme: ColorScheme {
        switch self {
        case .frost, .ember, .custom: return .light
        case .slate, .coppice, .aurora, .matrix: return .dark
        }
    }

    // Whether this theme's signature look renders on a dark background.
    // Used by swatches and the wordmark halo.
    var isDark: Bool { defaultColorScheme == .dark }

    // Whether this theme uses the per-character animated canvas renderer.
    // Views check this instead of comparing against the .matrix case directly,
    // keeping the view decoupled from the theme enum.
    var isAnimated: Bool { self == .matrix }

    // ── Swatch preview colours ───────────────────────────────────────────────
    // These two colours are enough to communicate a theme's identity in a
    // small tile without building the full palette for every swatch render.

    var swatchBackground: Color {
        switch self {
        case .frost:   return Color(red: 0.94, green: 0.96, blue: 0.99)
        case .slate:   return Color(red: 0.05, green: 0.07, blue: 0.13)
        case .coppice: return Color(red: 0.09, green: 0.13, blue: 0.08)
        case .ember:   return Color(red: 0.99, green: 0.95, blue: 0.91)
        case .aurora:  return Color(red: 0.04, green: 0.06, blue: 0.11)
        case .matrix:  return Color(red: 0.01, green: 0.04, blue: 0.02)
        case .custom:  return Color(UIColor.systemBackground)
        }
    }

    var swatchAccent: Color {
        switch self {
        case .frost:   return Color(red: 0.14, green: 0.44, blue: 0.75)
        case .slate:   return Color(red: 0.35, green: 0.65, blue: 1.00)
        case .coppice: return Color(red: 0.40, green: 0.75, blue: 0.35)
        case .ember:   return Color(red: 0.88, green: 0.36, blue: 0.16)
        case .aurora:  return Color(red: 0.35, green: 0.95, blue: 0.80)
        case .matrix:  return Color(red: 0.32, green: 1.00, blue: 0.45)
        case .custom:  return Color.accentColor
        }
    }

    // ── Full palette ─────────────────────────────────────────────────────────
    // customAccent is only used by the .custom case; all other themes ignore it.
    // colorScheme selects between the light and dark variant of each theme.
    // Passing no colorScheme returns the theme's signature (default) variant.

    func palette(customAccent: Color = .accentColor, colorScheme: ColorScheme? = nil) -> ThemePalette {
        let scheme = colorScheme ?? defaultColorScheme
        switch self {

        // ─── Frost ───────────────────────────────────────────────────────────
        // Light: cool blue-grey — the original signature palette.
        // Dark:  deep midnight blue, same orange/teal/blue digit accents brightened for dark bg.
        case .frost:
            if scheme == .dark {
                return ThemePalette(
                    background: Color(red: 0.048, green: 0.078, blue: 0.149),
                    surface:    Color(red: 0.082, green: 0.122, blue: 0.208),
                    border:     Color(red: 0.180, green: 0.255, blue: 0.388).opacity(0.50),
                    ink:        Color(red: 0.878, green: 0.918, blue: 0.969),
                    mutedInk:   Color(red: 0.878, green: 0.918, blue: 0.969).opacity(0.45),
                    accent:     Color(red: 0.310, green: 0.620, blue: 0.980),
                    day:        Color(red: 1.000, green: 0.498, blue: 0.310),
                    month:      Color(red: 0.180, green: 0.780, blue: 0.820),
                    year:       Color(red: 0.420, green: 0.620, blue: 1.000),
                    heatNone:              Color(red: 0.082, green: 0.122, blue: 0.208),
                    heatFaint:             Color(red: 0.090, green: 0.165, blue: 0.305),
                    heatCool:              Color(red: 0.085, green: 0.205, blue: 0.400),
                    heatWarm:              Color(red: 0.210, green: 0.270, blue: 0.170),
                    heatHot:               Color(red: 0.295, green: 0.355, blue: 0.170),
                    heatOutOfMonth:        Color(red: 0.048, green: 0.078, blue: 0.149).opacity(0.60),
                    heatOutOfMonthForeground: Color(red: 0.878, green: 0.918, blue: 0.969).opacity(0.22)
                )
            }
            return ThemePalette(
                background: Color(red: 0.940, green: 0.961, blue: 0.988),
                surface:    Color.white.opacity(0.82),
                border:     Color.white.opacity(0.70),
                ink:        Color(red: 0.160, green: 0.210, blue: 0.270),
                mutedInk:   Color(red: 0.390, green: 0.460, blue: 0.550),
                accent:     Color(red: 0.140, green: 0.440, blue: 0.750),
                day:        Color(red: 0.880, green: 0.370, blue: 0.200),
                month:      Color(red: 0.120, green: 0.570, blue: 0.610),
                year:       Color(red: 0.270, green: 0.400, blue: 0.870),
                heatNone:              Color.white.opacity(0.72),
                heatFaint:             Color(red: 0.89, green: 0.95, blue: 0.99),
                heatCool:              Color(red: 0.77, green: 0.89, blue: 0.97),
                heatWarm:              Color(red: 0.99, green: 0.88, blue: 0.72),
                heatHot:               Color(red: 1.00, green: 0.77, blue: 0.60),
                heatOutOfMonth:        Color.white.opacity(0.36),
                heatOutOfMonthForeground: Color(red: 0.62, green: 0.68, blue: 0.74)
            )

        // ─── Slate ───────────────────────────────────────────────────────────
        // Dark: deep navy with electric blue accent — the signature look.
        // Light: soft cool blue-grey, same sky/indigo/blue digit accents.
        case .slate:
            if scheme == .light {
                return ThemePalette(
                    background: Color(red: 0.910, green: 0.925, blue: 0.958),
                    surface:    Color.white.opacity(0.88),
                    border:     Color(red: 0.690, green: 0.749, blue: 0.851).opacity(0.55),
                    ink:        Color(red: 0.051, green: 0.071, blue: 0.149),
                    mutedInk:   Color(red: 0.200, green: 0.268, blue: 0.388),
                    accent:     Color(red: 0.120, green: 0.420, blue: 0.820),
                    day:        Color(red: 0.082, green: 0.518, blue: 0.780),
                    month:      Color(red: 0.318, green: 0.196, blue: 0.780),
                    year:       Color(red: 0.120, green: 0.380, blue: 0.820),
                    heatNone:              Color.white.opacity(0.80),
                    heatFaint:             Color(red: 0.86, green: 0.92, blue: 0.98),
                    heatCool:              Color(red: 0.74, green: 0.85, blue: 0.96),
                    heatWarm:              Color(red: 0.88, green: 0.94, blue: 0.80),
                    heatHot:               Color(red: 0.76, green: 0.90, blue: 0.68),
                    heatOutOfMonth:        Color.white.opacity(0.42),
                    heatOutOfMonthForeground: Color(red: 0.52, green: 0.60, blue: 0.72)
                )
            }
            return ThemePalette(
                background: Color(red: 0.051, green: 0.071, blue: 0.118),
                surface:    Color(red: 0.090, green: 0.118, blue: 0.176),
                border:     Color(red: 0.200, green: 0.255, blue: 0.349).opacity(0.50),
                ink:        Color(red: 0.894, green: 0.922, blue: 0.965),
                mutedInk:   Color(red: 0.894, green: 0.922, blue: 0.965).opacity(0.45),
                accent:     Color(red: 0.345, green: 0.651, blue: 1.000),
                day:        Color(red: 0.310, green: 0.831, blue: 1.000),
                month:      Color(red: 0.549, green: 0.424, blue: 1.000),
                year:       Color(red: 0.345, green: 0.651, blue: 1.000),
                heatNone:              Color(red: 0.090, green: 0.118, blue: 0.176),
                heatFaint:             Color(red: 0.110, green: 0.180, blue: 0.310),
                heatCool:              Color(red: 0.100, green: 0.220, blue: 0.420),
                heatWarm:              Color(red: 0.200, green: 0.280, blue: 0.180),
                heatHot:               Color(red: 0.280, green: 0.360, blue: 0.180),
                heatOutOfMonth:        Color(red: 0.051, green: 0.071, blue: 0.118).opacity(0.60),
                heatOutOfMonthForeground: Color(red: 0.894, green: 0.922, blue: 0.965).opacity(0.20)
            )

        // ─── Coppice ─────────────────────────────────────────────────────────
        // Dark: deep forest floor, bright leaf green accent — the signature look.
        // Light: soft sage parchment, dark forest ink, same mint/teal/lime digits.
        case .coppice:
            if scheme == .light {
                return ThemePalette(
                    background: Color(red: 0.910, green: 0.945, blue: 0.896),
                    surface:    Color.white.opacity(0.86),
                    border:     Color(red: 0.620, green: 0.749, blue: 0.588).opacity(0.55),
                    ink:        Color(red: 0.059, green: 0.118, blue: 0.047),
                    mutedInk:   Color(red: 0.180, green: 0.310, blue: 0.149),
                    accent:     Color(red: 0.220, green: 0.588, blue: 0.180),
                    day:        Color(red: 0.059, green: 0.569, blue: 0.290),
                    month:      Color(red: 0.078, green: 0.439, blue: 0.310),
                    year:       Color(red: 0.220, green: 0.545, blue: 0.078),
                    heatNone:              Color.white.opacity(0.78),
                    heatFaint:             Color(red: 0.88, green: 0.96, blue: 0.86),
                    heatCool:              Color(red: 0.76, green: 0.93, blue: 0.74),
                    heatWarm:              Color(red: 0.82, green: 0.95, blue: 0.66),
                    heatHot:               Color(red: 0.70, green: 0.92, blue: 0.54),
                    heatOutOfMonth:        Color.white.opacity(0.42),
                    heatOutOfMonthForeground: Color(red: 0.40, green: 0.56, blue: 0.35)
                )
            }
            return ThemePalette(
                background: Color(red: 0.090, green: 0.129, blue: 0.082),
                surface:    Color(red: 0.141, green: 0.188, blue: 0.129),
                border:     Color(red: 0.239, green: 0.318, blue: 0.216).opacity(0.50),
                ink:        Color(red: 0.906, green: 0.941, blue: 0.898),
                mutedInk:   Color(red: 0.906, green: 0.941, blue: 0.898).opacity(0.45),
                accent:     Color(red: 0.400, green: 0.753, blue: 0.345),
                day:        Color(red: 0.447, green: 0.953, blue: 0.647),
                month:      Color(red: 0.349, green: 0.753, blue: 0.549),
                year:       Color(red: 0.596, green: 0.894, blue: 0.420),
                heatNone:              Color(red: 0.141, green: 0.188, blue: 0.129),
                heatFaint:             Color(red: 0.120, green: 0.220, blue: 0.140),
                heatCool:              Color(red: 0.100, green: 0.270, blue: 0.160),
                heatWarm:              Color(red: 0.200, green: 0.300, blue: 0.100),
                heatHot:               Color(red: 0.270, green: 0.400, blue: 0.100),
                heatOutOfMonth:        Color(red: 0.090, green: 0.129, blue: 0.082).opacity(0.60),
                heatOutOfMonthForeground: Color(red: 0.906, green: 0.941, blue: 0.898).opacity(0.20)
            )

        // ─── Ember ───────────────────────────────────────────────────────────
        // Light: warm parchment with terracotta accent — the signature look.
        // Dark:  deep charred mahogany, cream ink, same terracotta/rose/plum digits.
        case .ember:
            if scheme == .dark {
                return ThemePalette(
                    background: Color(red: 0.102, green: 0.055, blue: 0.031),
                    surface:    Color(red: 0.165, green: 0.094, blue: 0.059),
                    border:     Color(red: 0.388, green: 0.231, blue: 0.149).opacity(0.50),
                    ink:        Color(red: 0.969, green: 0.929, blue: 0.882),
                    mutedInk:   Color(red: 0.969, green: 0.929, blue: 0.882).opacity(0.45),
                    accent:     Color(red: 0.951, green: 0.451, blue: 0.208),
                    day:        Color(red: 0.980, green: 0.518, blue: 0.278),
                    month:      Color(red: 0.929, green: 0.310, blue: 0.459),
                    year:       Color(red: 0.749, green: 0.278, blue: 0.749),
                    heatNone:              Color(red: 0.165, green: 0.094, blue: 0.059),
                    heatFaint:             Color(red: 0.220, green: 0.118, blue: 0.071),
                    heatCool:              Color(red: 0.290, green: 0.149, blue: 0.078),
                    heatWarm:              Color(red: 0.329, green: 0.122, blue: 0.051),
                    heatHot:               Color(red: 0.420, green: 0.149, blue: 0.059),
                    heatOutOfMonth:        Color(red: 0.102, green: 0.055, blue: 0.031).opacity(0.60),
                    heatOutOfMonthForeground: Color(red: 0.969, green: 0.929, blue: 0.882).opacity(0.22)
                )
            }
            return ThemePalette(
                background: Color(red: 0.988, green: 0.953, blue: 0.910),
                surface:    Color(red: 1.000, green: 0.980, blue: 0.965),
                border:     Color(red: 0.875, green: 0.784, blue: 0.741).opacity(0.55),
                ink:        Color(red: 0.176, green: 0.094, blue: 0.059),
                mutedInk:   Color(red: 0.176, green: 0.094, blue: 0.059).opacity(0.45),
                accent:     Color(red: 0.851, green: 0.361, blue: 0.157),
                day:        Color(red: 0.851, green: 0.361, blue: 0.157),
                month:      Color(red: 0.780, green: 0.188, blue: 0.345),
                year:       Color(red: 0.565, green: 0.157, blue: 0.565),
                heatNone:              Color(red: 1.000, green: 0.980, blue: 0.965).opacity(0.80),
                heatFaint:             Color(red: 0.99, green: 0.94, blue: 0.87),
                heatCool:              Color(red: 0.98, green: 0.88, blue: 0.78),
                heatWarm:              Color(red: 0.99, green: 0.82, blue: 0.68),
                heatHot:               Color(red: 1.00, green: 0.74, blue: 0.56),
                heatOutOfMonth:        Color(red: 0.988, green: 0.953, blue: 0.910).opacity(0.55),
                heatOutOfMonthForeground: Color(red: 0.176, green: 0.094, blue: 0.059).opacity(0.28)
            )

        // ─── Aurora ──────────────────────────────────────────────────────────
        // Dark: near-black with electric teal — the signature look.
        // Light: pearl white with deep midnight ink, same teal/periwinkle/violet digits.
        case .aurora:
            if scheme == .light {
                return ThemePalette(
                    background: Color(red: 0.929, green: 0.957, blue: 0.988),
                    surface:    Color.white.opacity(0.90),
                    border:     Color(red: 0.600, green: 0.729, blue: 0.859).opacity(0.50),
                    ink:        Color(red: 0.039, green: 0.078, blue: 0.149),
                    mutedInk:   Color(red: 0.149, green: 0.259, blue: 0.420),
                    accent:     Color(red: 0.059, green: 0.651, blue: 0.561),
                    day:        Color(red: 0.027, green: 0.620, blue: 0.529),
                    month:      Color(red: 0.200, green: 0.318, blue: 0.780),
                    year:       Color(red: 0.490, green: 0.149, blue: 0.769),
                    heatNone:              Color.white.opacity(0.80),
                    heatFaint:             Color(red: 0.86, green: 0.94, blue: 0.98),
                    heatCool:              Color(red: 0.73, green: 0.88, blue: 0.97),
                    heatWarm:              Color(red: 0.80, green: 0.94, blue: 0.90),
                    heatHot:               Color(red: 0.67, green: 0.92, blue: 0.84),
                    heatOutOfMonth:        Color.white.opacity(0.42),
                    heatOutOfMonthForeground: Color(red: 0.40, green: 0.55, blue: 0.72)
                )
            }
            return ThemePalette(
                background: Color(red: 0.039, green: 0.059, blue: 0.098),
                surface:    Color(red: 0.075, green: 0.102, blue: 0.161),
                border:     Color(red: 0.149, green: 0.212, blue: 0.298).opacity(0.50),
                ink:        Color(red: 0.910, green: 0.953, blue: 1.000),
                mutedInk:   Color(red: 0.910, green: 0.953, blue: 1.000).opacity(0.45),
                accent:     Color(red: 0.349, green: 0.953, blue: 0.800),
                day:        Color(red: 0.349, green: 0.953, blue: 0.800),
                month:      Color(red: 0.502, green: 0.651, blue: 1.000),
                year:       Color(red: 0.753, green: 0.400, blue: 1.000),
                heatNone:              Color(red: 0.075, green: 0.102, blue: 0.161),
                heatFaint:             Color(red: 0.080, green: 0.160, blue: 0.220),
                heatCool:              Color(red: 0.070, green: 0.190, blue: 0.280),
                heatWarm:              Color(red: 0.100, green: 0.230, blue: 0.200),
                heatHot:               Color(red: 0.120, green: 0.310, blue: 0.260),
                heatOutOfMonth:        Color(red: 0.039, green: 0.059, blue: 0.098).opacity(0.60),
                heatOutOfMonthForeground: Color(red: 0.910, green: 0.953, blue: 1.000).opacity(0.20)
            )

        // ─── Matrix ──────────────────────────────────────────────────────────
        // Dark:  phosphor green-on-black — the signature CRT look.
        // Light: terminal printout — off-white paper with dark ink-green digits.
        case .matrix:
            if scheme == .light {
                return ThemePalette(
                    background: Color(red: 0.957, green: 0.961, blue: 0.941),
                    surface:    Color.white.opacity(0.92),
                    border:     Color(red: 0.498, green: 0.659, blue: 0.482).opacity(0.45),
                    ink:        Color(red: 0.059, green: 0.239, blue: 0.082),
                    mutedInk:   Color(red: 0.118, green: 0.361, blue: 0.141),
                    accent:     Color(red: 0.078, green: 0.490, blue: 0.141),
                    day:        Color(red: 0.039, green: 0.490, blue: 0.141),
                    month:      Color(red: 0.059, green: 0.408, blue: 0.118),
                    year:       Color(red: 0.078, green: 0.529, blue: 0.157),
                    heatNone:              Color.white.opacity(0.80),
                    heatFaint:             Color(red: 0.88, green: 0.96, blue: 0.87),
                    heatCool:              Color(red: 0.74, green: 0.92, blue: 0.74),
                    heatWarm:              Color(red: 0.76, green: 0.95, blue: 0.65),
                    heatHot:               Color(red: 0.62, green: 0.91, blue: 0.52),
                    heatOutOfMonth:        Color.white.opacity(0.42),
                    heatOutOfMonthForeground: Color(red: 0.35, green: 0.55, blue: 0.35)
                )
            }
            return ThemePalette(
                background: Color(red: 0.012, green: 0.028, blue: 0.016),
                surface:    Color(red: 0.026, green: 0.075, blue: 0.039),
                border:     Color(red: 0.231, green: 0.800, blue: 0.384).opacity(0.26),
                ink:        Color(red: 0.755, green: 1.000, blue: 0.815),
                mutedInk:   Color(red: 0.482, green: 0.910, blue: 0.576).opacity(0.72),
                accent:     Color(red: 0.341, green: 1.000, blue: 0.475),
                day:        Color(red: 0.651, green: 1.000, blue: 0.706),
                month:      Color(red: 0.502, green: 1.000, blue: 0.620),
                year:       Color(red: 0.341, green: 1.000, blue: 0.475),
                heatNone:              Color(red: 0.026, green: 0.075, blue: 0.039),
                heatFaint:             Color(red: 0.041, green: 0.145, blue: 0.069),
                heatCool:              Color(red: 0.065, green: 0.235, blue: 0.108),
                heatWarm:              Color(red: 0.110, green: 0.380, blue: 0.163),
                heatHot:               Color(red: 0.155, green: 0.560, blue: 0.220),
                heatOutOfMonth:        Color(red: 0.012, green: 0.028, blue: 0.016).opacity(0.70),
                heatOutOfMonthForeground: Color(red: 0.482, green: 0.910, blue: 0.576).opacity(0.18)
            )

        // ─── Custom ──────────────────────────────────────────────────────────
        // Defers to system adaptive colours so light/dark mode is respected.
        // Digit colours derive from the chosen accent: full, 75%, 50% opacity
        // gives a harmonised triad without needing a second colour picker.
        case .custom:
            return ThemePalette(
                background: Color(UIColor.systemGroupedBackground),
                surface:    Color(UIColor.secondarySystemGroupedBackground),
                border:     Color(UIColor.separator).opacity(0.45),
                ink:        Color(UIColor.label),
                mutedInk:   Color(UIColor.secondaryLabel),
                accent:     customAccent,
                day:        customAccent,
                month:      customAccent.opacity(0.78),
                year:       customAccent.opacity(0.54),
                heatNone:              Color(UIColor.secondarySystemGroupedBackground),
                heatFaint:             Color(UIColor.systemBlue).opacity(0.12),
                heatCool:              Color(UIColor.systemBlue).opacity(0.25),
                heatWarm:              Color(UIColor.systemOrange).opacity(0.25),
                heatHot:               Color(UIColor.systemOrange).opacity(0.45),
                heatOutOfMonth:        Color(UIColor.systemGroupedBackground).opacity(0.55),
                heatOutOfMonthForeground: Color(UIColor.tertiaryLabel)
            )
        }
    }
}
