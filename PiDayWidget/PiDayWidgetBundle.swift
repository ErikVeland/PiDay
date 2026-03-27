import WidgetKit
import SwiftUI
import AppIntents

// WHY: @main on a WidgetBundle (not a single Widget) lets you declare multiple
// widget configurations in one extension. Here we have one: PiDayWidget.
// If you later add a Lock Screen widget or an interactive widget, you add them
// here and the system discovers them automatically.
@main
struct PiDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        PiDayWidget()
        PiDayLockScreenWidget()
    }
}

// PiDayWidget ties together the three components:
//   provider  → generates the timeline entries
//   content   → renders each entry into a SwiftUI view
//   configuration → sets the display name, description, and supported sizes
struct PiDayWidget: Widget {
    // This identifier is used by WidgetKit to track this widget across updates.
    // It must be unique per widget type and should never change once released.
    let kind = "academy.glasscode.piday.widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetThemeIntent.self, provider: PiDayProvider()) { entry in
            // WHY we pass the entry down rather than using @Environment:
            // The widget view is rendered in a sandboxed process with no
            // ViewModel — the entry IS the entire data model for this render.
            PiDayWidgetView(entry: entry)
        }
        .configurationDisplayName("PiDay")
        .description("See where today's date appears in the digits of pi.")
        // WHY all three families: .systemSmall for a glance, .systemMedium
        // for an excerpt, and .systemLarge for the nerdy stats dashboard.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // contentMarginsDisabled() is needed if you want to draw to the full
        // widget rect (e.g. for a full-bleed gradient background).
        // With padding(14) inside each view, the default margins are fine.
    }
}

// MARK: - Lock Screen / StandBy accessory widget

// WHY a separate Widget (not just more families on PiDayWidget):
// Accessory families and system families need different WidgetConfiguration
// keys and the system treats them as distinct user-addable items.
// Keeping them separate also lets you give the Lock Screen widget its own
// display name in the widget gallery.
struct PiDayLockScreenWidget: Widget {
    let kind = "academy.glasscode.piday.accessory"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetThemeIntent.self, provider: PiDayProvider()) { entry in
            PiDayWidgetView(entry: entry)
        }
        .configurationDisplayName("PiDay")
        .description("See where today's date appears in pi — on your Lock Screen.")
        // WHY all three accessory families: each occupies a different slot on
        // the Lock Screen and Apple Watch. Circular = corner/Watch; Rectangular =
        // below-clock bar; Inline = single text line above the clock.
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

enum WidgetThemeChoice: String, AppEnum {
    case matchApp
    case frost
    case slate
    case coppice
    case ember
    case aurora
    case matrix
    case custom

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Theme")
    static let caseDisplayRepresentations: [WidgetThemeChoice: DisplayRepresentation] = [
        .matchApp: DisplayRepresentation(title: "Match App"),
        .frost: DisplayRepresentation(title: "Frost"),
        .slate: DisplayRepresentation(title: "Slate"),
        .coppice: DisplayRepresentation(title: "Coppice"),
        .ember: DisplayRepresentation(title: "Ember"),
        .aurora: DisplayRepresentation(title: "Aurora"),
        .matrix: DisplayRepresentation(title: "Matrix"),
        .custom: DisplayRepresentation(title: "Custom")
    ]

    var appTheme: AppTheme? {
        switch self {
        case .matchApp: return nil
        case .frost: return .frost
        case .slate: return .slate
        case .coppice: return .coppice
        case .ember: return .ember
        case .aurora: return .aurora
        case .matrix: return .matrix
        case .custom: return .custom
        }
    }
}

enum WidgetAppearanceChoice: String, AppEnum {
    case matchApp
    case system
    case light
    case dark

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Appearance")
    static let caseDisplayRepresentations: [WidgetAppearanceChoice: DisplayRepresentation] = [
        .matchApp: DisplayRepresentation(title: "Match App"),
        .system: DisplayRepresentation(title: "System"),
        .light: DisplayRepresentation(title: "Light"),
        .dark: DisplayRepresentation(title: "Dark")
    ]

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .matchApp, .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct WidgetThemeIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget Appearance"
    static let description = IntentDescription("Choose whether this widget matches the app or uses its own theme and appearance.")

    @Parameter(title: "Theme")
    var theme: WidgetThemeChoice?

    @Parameter(title: "Appearance")
    var appearance: WidgetAppearanceChoice?

    init() {
        theme = .matchApp
        appearance = .matchApp
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Theme: \(\.$theme), Appearance: \(\.$appearance)")
    }
}
