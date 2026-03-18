import SwiftUI
import WidgetKit

// WHY: The medium widget (~329×155pt) has roughly twice the width of small.
// The killer feature here is showing actual pi digits around the match —
// the same excerpt that makes the main app canvas special, in condensed form.
// This gives users an at-a-glance feel for WHERE in pi their date lives.

struct WidgetMediumView: View {
    let entry: PiDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Spacer()
            mainContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .containerBackground(entry.palette.background, for: .widget)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            PiWordmark(palette: entry.palette)
            Spacer()
            HStack(spacing: 8) {
                Button(intent: AdvanceDateIntent(direction: .previous)) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)

                Button(intent: AdvanceDateIntent(direction: .next)) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.palette.mutedInk)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        switch entry.result {

        case let .found(query, format, position, excerpt):
            VStack(alignment: .leading, spacing: 6) {
                excerptLine(excerpt: excerpt, query: query, format: format)
                metadataLine(format: format, position: position)
            }

        case let .notFound(heroQuery, format):
            VStack(alignment: .leading, spacing: 6) {
                // Show the hero query in muted color with a strikethrough-style opacity
                // to signal "this was searched but not found."
                Text(heroQuery)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(entry.palette.mutedInk.opacity(0.4))
                Text("\(format.displayName)  ·  not found in first 5 billion digits")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            }

        case .outOfRange:
            VStack(alignment: .leading, spacing: 6) {
                Text("Outside bundled index range")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(entry.palette.mutedInk)
                Text("Open PiDay to search live")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk.opacity(0.7))
            }
        }
    }

    // MARK: - Excerpt line

    // Renders the pi digit excerpt with the matching sequence color-coded.
    // e.g.:  …41592653 [14][03][2026] 897932384…
    //                   day  mo  year
    private func excerptLine(excerpt: WidgetExcerpt, query: String, format: DateFormatOption) -> some View {
        let parts = format.queryParts(from: query)
        let styledText =
            Text(excerpt.before).foregroundStyle(entry.palette.mutedInk.opacity(0.55))
            + Text(parts.day).foregroundStyle(entry.palette.day)
            + Text(parts.month).foregroundStyle(entry.palette.month)
            + Text(parts.year).foregroundStyle(entry.palette.year)
            + Text(excerpt.after).foregroundStyle(entry.palette.mutedInk.opacity(0.55))

        return styledText
            .font(Font.system(.callout, design: .monospaced, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func metadataLine(format: DateFormatOption, position: Int) -> some View {
        Text("\(format.displayName)  ·  digit \(position.formatted(.number))")
            .font(.caption)
            .foregroundStyle(entry.palette.mutedInk)
    }
}

// MARK: - Preview

#Preview("Medium — found", as: .systemMedium) {
    PiDayWidget()
} timeline: {
    PiDayEntry.placeholder
}

#Preview("Medium — not found", as: .systemMedium) {
    PiDayWidget()
} timeline: {
    PiDayEntry.notFoundSample
}

#Preview("Medium — out of range", as: .systemMedium) {
    PiDayWidget()
} timeline: {
    PiDayEntry.outOfRangeSample
}
