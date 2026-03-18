import SwiftUI
import UniformTypeIdentifiers

// MARK: - Transferable wrapper

// WHY a custom Transferable instead of sharing plain text:
// `ShareLink(item: someString)` gives the receiver plain text.
// `ShareLink(item: ShareableCard(...))` gives the receiver a PNG image —
// the kind of thing people actually post to Instagram or iMessage.
//
// The Transferable protocol bridges our SwiftUI view into the system share sheet.
// `DataRepresentation` says "when the receiver wants a PNG, render it for them."
struct ShareableCard: Transferable {
    let date: Date
    let bestMatch: BestPiMatch?
    let query: String
    let format: DateFormatOption
    let displayedPosition: Int?
    let excerptRadius: Int
    // WHY palette: the share card previously always used the Frost (default) palette
    // regardless of the user's chosen theme. Passing the resolved palette ensures
    // the shared image matches what the user sees in the app.
    let palette: ThemePalette

    // WHY @MainActor on render(): ImageRenderer is MainActor-isolated.
    // The DataRepresentation closure is async, so we hop to MainActor here.
    @MainActor
    func render() -> UIImage? {
        let card = ShareCardView(
            date: date,
            bestMatch: bestMatch,
            query: query,
            format: format,
            displayedPosition: displayedPosition,
            excerptRadius: excerptRadius,
            palette: palette
        )
        .frame(width: 360, height: 360)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0   // @3x = 1080×1080 — standard Instagram resolution
        return renderer.uiImage
    }

    static var transferRepresentation: some TransferRepresentation {
        // exportedContentType: .png tells the share sheet this is an image.
        // The system uses this to decide which apps appear in the share sheet
        // (e.g. Photos, Instagram, Messages all accept .png).
        DataRepresentation(exportedContentType: .png) { card in
            await MainActor.run {
                card.render()?.pngData() ?? Data()
            }
        }
    }
}

// MARK: - Card view

// WHY no @Environment here: this view is rendered by ImageRenderer outside the
// normal SwiftUI view hierarchy. @Environment values (like AppViewModel) are not
// available in that context. All data must come through the initializer.
struct ShareCardView: View {
    let date: Date
    let bestMatch: BestPiMatch?
    let query: String
    let format: DateFormatOption
    let displayedPosition: Int?
    let excerptRadius: Int
    let palette: ThemePalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background — uses the user's active theme colour
            palette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .firstTextBaseline) {
                    wordmark
                    Spacer()
                    Text(date, format: .dateTime.day().month(.wide).year())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.mutedInk)
                }
                .padding(.bottom, 32)

                Spacer()

                // Main result
                resultSection

                Spacer()

                // Footer
                Text("Find your date in π · piday.app")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.mutedInk.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(28)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var resultSection: some View {
        if let match = bestMatch, let position = displayedPosition {
            foundSection(match: match, position: position)
        } else {
            notFoundSection
        }
    }

    private func foundSection(match: BestPiMatch, position: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Colored digit sequence — the hero element
            coloredQueryText(query, format: format)
                .font(.system(size: 38, weight: .bold, design: .monospaced))

            // Position
            Text("digit \(position.formatted(.number))")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.mutedInk)

            // Format label
            Text(format.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.mutedInk.opacity(0.7))
                .padding(.bottom, 8)

            // Excerpt strip — shows the actual pi digits around the match
            excerptLine(match: match)
        }
    }

    private var notFoundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(query)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.mutedInk.opacity(0.35))

            Text("Not in the first 5 billion\ndigits of pi")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.mutedInk)
                .lineSpacing(4)
        }
    }

    // MARK: - Subviews

    private var wordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: -2) {
            Text("∏")
                .font(.system(size: 16, weight: .black, design: .serif))
                .italic()
            Text("day")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(palette.ink.opacity(0.8))
    }

    private func coloredQueryText(_ query: String, format: DateFormatOption) -> Text {
        let parts = format.queryParts(from: query)
        return Text(parts.day).foregroundStyle(palette.day)
            + Text(parts.month).foregroundStyle(palette.month)
            + Text(parts.year).foregroundStyle(palette.year)
    }

    private func excerptLine(match: BestPiMatch) -> some View {
        // Trim the excerpt to a short window around the match for the card
        let radius = 12
        let queryOffset = min(excerptRadius, match.storedPosition - 1)
        let excerpt = match.excerpt

        let result: (before: String, after: String) = {
            guard queryOffset + match.query.count <= excerpt.count else {
                return ("", "")
            }
            let qIdx = excerpt.index(excerpt.startIndex, offsetBy: queryOffset)
            let qEnd = excerpt.index(qIdx, offsetBy: match.query.count)
            let bStart = excerpt.index(qIdx, offsetBy: -min(radius, queryOffset), limitedBy: excerpt.startIndex) ?? excerpt.startIndex
            let aEnd = excerpt.index(qEnd, offsetBy: radius, limitedBy: excerpt.endIndex) ?? excerpt.endIndex
            return ("…" + String(excerpt[bStart..<qIdx]), String(excerpt[qEnd..<aEnd]) + "…")
        }()

        let parts = format.queryParts(from: match.query)
        return (
            Text(result.before).foregroundStyle(palette.mutedInk.opacity(0.45))
            + Text(parts.day).foregroundStyle(palette.day)
            + Text(parts.month).foregroundStyle(palette.month)
            + Text(parts.year).foregroundStyle(palette.year)
            + Text(result.after).foregroundStyle(palette.mutedInk.opacity(0.45))
        )
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
    }
}
