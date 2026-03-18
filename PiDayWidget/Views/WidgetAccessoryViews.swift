import SwiftUI
import WidgetKit

// WHY three separate view types (not one view with switch):
// Each accessory family has a completely different shape and information budget.
// .accessoryCircular is ~44pt circle — you can fit ONE number.
// .accessoryRectangular is a slim bar — you can fit a date and a short label.
// .accessoryInline is a single line of text — one piece of info only.
// Keeping them separate makes each layout easy to iterate without affecting the others.

// MARK: - Circular (e.g. Watch complications, Lock Screen corner)

struct WidgetCircularView: View {
    let entry: PiDayEntry

    var body: some View {
        ZStack {
            // WHY AccessoryWidgetBackground: on Lock Screen, the system composites
            // your widget over the wallpaper. This background adapts automatically
            // to light/dark wallpapers and renders correctly in vibrant mode.
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Text("π")
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)

                Group {
                    switch entry.result {
                    case let .found(_, _, position, _):
                        Text(compactPosition(position))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    case .notFound, .outOfRange:
                        Text("—")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        // WHY .widgetAccentable(): marks this view as the "accent" element.
        // When the user tints their Lock Screen, accented views pick up that color.
        .widgetAccentable()
    }

    // Compact position format: 47832 → "47K", 1234567 → "1.2M"
    private func compactPosition(_ position: Int) -> String {
        if position < 1_000 { return "\(position)" }
        if position < 10_000 { return "\(position / 1_000).\(position % 1_000 / 100)K" }
        if position < 1_000_000 { return "\(position / 1_000)K" }
        return "\(position / 1_000_000)M"
    }
}

// MARK: - Rectangular (Lock Screen, StandBy horizontal bar)

struct WidgetRectangularView: View {
    let entry: PiDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Date line — always shown
            Text(entry.date, style: .date)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Result line
            switch entry.result {
            case let .found(query, format, position, _):
                HStack(spacing: 6) {
                    ColoredQueryText(
                        query: query,
                        format: format,
                        font: .system(.caption, design: .monospaced, weight: .bold),
                        palette: entry.palette
                    )
                    Text("· digit \(position.formatted(.number))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            case let .notFound(heroQuery, _):
                Text("\(heroQuery) · not found")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
            case .outOfRange:
                Text("Outside index range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}

// MARK: - Inline (Lock Screen single-line text above the clock)

struct WidgetInlineView: View {
    let entry: PiDayEntry

    var body: some View {
        // .accessoryInline supports only a single Text or Label.
        // WHY no styling: inline widgets render in the system's chosen color
        // automatically. Custom foreground colors are ignored.
        switch entry.result {
        case let .found(query, _, position, _):
            Text("π \(query) · \(position.formatted(.number))")
        case let .notFound(heroQuery, _):
            Text("π \(heroQuery) · not found")
        case .outOfRange:
            Text("π · out of range")
        }
    }
}

// MARK: - Previews

#Preview("Circular — found", as: .accessoryCircular) {
    PiDayWidget()
} timeline: {
    PiDayEntry.placeholder
}

#Preview("Rectangular — found", as: .accessoryRectangular) {
    PiDayWidget()
} timeline: {
    PiDayEntry.placeholder
}

#Preview("Inline — found", as: .accessoryInline) {
    PiDayWidget()
} timeline: {
    PiDayEntry.placeholder
}
