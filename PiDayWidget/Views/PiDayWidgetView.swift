import SwiftUI
import WidgetKit

// WHY: This is the root view the widget configuration points to.
// Its only job is to read the widget family from the environment and
// dispatch to the right layout. Every size can have completely different
// information density — the small widget shows a single result,
// the medium shows an excerpt of actual pi digits.

struct PiDayWidgetView: View {
    let entry: PiDayEntry

    // @Environment(\.widgetFamily) tells you which size slot the widget
    // is currently filling. You never hard-code sizes — you adapt to the family.
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                WidgetSmallView(entry: entry)
            case .systemMedium:
                WidgetMediumView(entry: entry)
            case .accessoryCircular:
                // WHY no .containerBackground: accessory widgets use AccessoryWidgetBackground()
                // directly inside the view. Adding .containerBackground here would double-apply it.
                WidgetCircularView(entry: entry)
            case .accessoryRectangular:
                WidgetRectangularView(entry: entry)
            case .accessoryInline:
                WidgetInlineView(entry: entry)
            default:
                WidgetSmallView(entry: entry)
            }
        }
        .preferredColorScheme(entry.preferredColorScheme)
    }
}

// MARK: - Shared subviews

// PiWordmark is shared across both size layouts.
// It's small and subtle — the widget isn't the place for branding,
// but a tiny mark helps users recognize which app the widget belongs to.
struct PiWordmark: View {
    let palette: ThemePalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: -2) {
            Text("∏")
                .font(.system(size: 13, weight: .black, design: .serif))
                .italic()
            Text("day")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(palette.ink.opacity(0.7))
    }
}

// ColoredQueryText renders the digit sequence with day/month/year in distinct colors.
// Defined here (not in each size view) so both sizes render it identically.
// WHY Text concatenation: it's the only way to mix foreground colors within a
// single run of text without breaking font metrics or spacing.
struct ColoredQueryText: View {
    let query: String
    let format: DateFormatOption
    let date: Date
    let font: Font
    let palette: ThemePalette

    var body: some View {
        let parts = format.queryParts(from: query, date: date)
        return (
            Text(parts.day).foregroundStyle(palette.day)
            + Text(parts.month).foregroundStyle(palette.month)
            + Text(parts.year).foregroundStyle(palette.year)
        )
        .font(font)
    }
}
