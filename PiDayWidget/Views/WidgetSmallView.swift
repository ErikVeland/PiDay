import SwiftUI
import WidgetKit

// WHY: The small widget (~155×155pt) has room for one number, a label,
// and a date line. Keep it focused — one insight at a glance.
// Don't try to cram in everything the app shows.

struct WidgetSmallView: View {
    let entry: PiDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PiWordmark(palette: entry.palette)

            Spacer()

            resultSection

            Spacer(minLength: 6)

            footerRow
        }
        .padding(14)
        // WHY containerBackground: iOS 17 requires this instead of .background().
        // The system handles corner clipping, StandBy mode, and Lock Screen
        // rendering automatically. Using .background() gives you a black widget.
        .containerBackground(entry.palette.background, for: .widget)
    }

    @ViewBuilder
    private var resultSection: some View {
        switch entry.result {

        case let .found(query, format, position, _):
            // The excerpt is available but we don't show it in the small widget —
            // there isn't room. We show it in the medium widget instead.
            VStack(alignment: .leading, spacing: 4) {
                ColoredQueryText(
                    query: query,
                    format: format,
                    font: .system(.title3, design: .monospaced, weight: .bold),
                    palette: entry.palette
                )
                Text("digit \(position.formatted(.number))")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            }

        case let .notFound(heroQuery, _):
            VStack(alignment: .leading, spacing: 4) {
                Text(heroQuery)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(entry.palette.mutedInk.opacity(0.4))
                Text("not in first 5B digits")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            }

        case .outOfRange:
            VStack(alignment: .leading, spacing: 4) {
                Text("—")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(entry.palette.mutedInk.opacity(0.4))
                Text("outside index range")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Button(intent: AdvanceDateIntent(direction: .previous)) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(entry.date, style: .date)
                .font(.caption2)
                .foregroundStyle(entry.palette.mutedInk)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(intent: AdvanceDateIntent(direction: .next)) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(entry.palette.mutedInk)
    }
}

// MARK: - Preview

// WHY #Preview with multiple entries: Xcode shows them all side by side,
// letting you check every visual state without running the app.
#Preview("Small — found", as: .systemSmall) {
    PiDayWidget()
} timeline: {
    PiDayEntry.placeholder
}

#Preview("Small — not found", as: .systemSmall) {
    PiDayWidget()
} timeline: {
    PiDayEntry.notFoundSample
}

#Preview("Small — out of range", as: .systemSmall) {
    PiDayWidget()
} timeline: {
    PiDayEntry.outOfRangeSample
}
