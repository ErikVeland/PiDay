import SwiftUI

struct WatchRootView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.lookupSummary == nil && model.errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = model.errorMessage {
                    VStack(spacing: 8) {
                        Text("PiDay")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PiPalette.logoInk)

                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                            .foregroundStyle(PiPalette.error)
                    }
                    .padding(12)
                } else {
                    NavigationLink {
                        WatchDetailView()
                    } label: {
                        HeroCard(
                            before: heroBefore,
                            match: model.primaryQuery,
                            after: heroAfter,
                            format: model.primaryFormat,
                            date: model.selectedDate
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await model.loadIfNeeded()
        }
    }

    private var heroBefore: String {
        heroParts.before
    }

    private var heroAfter: String {
        heroParts.after
    }

    private var heroParts: (before: String, after: String) {
        let chunkSize = 12
        guard let bestMatch else {
            let fallbackBefore = String(repeating: "31415926535897932384626433832795", count: 1)
            let fallbackAfter = String(repeating: "02884197169399375105820974944592", count: 1)
            let qLen = 8
            let spaces = (chunkSize - qLen) / 2
            let bCount = chunkSize * 2 + spaces
            let aCount = chunkSize * 2 + (chunkSize - spaces - qLen)
            return (String(fallbackBefore.prefix(bCount)), String(fallbackAfter.prefix(aCount)))
        }

        let query = bestMatch.query
        let excerpt = bestMatch.excerpt
        guard let range = excerpt.range(of: query) else {
            return ("", "")
        }

        let leadingSpaces = max(0, (chunkSize - query.count) / 2)
        let desiredBeforeCount = chunkSize * 2 + leadingSpaces
        
        let beforeStr = String(String(excerpt[..<range.lowerBound]).suffix(desiredBeforeCount))
        let paddedBefore = String(repeating: " ", count: max(0, desiredBeforeCount - beforeStr.count)) + beforeStr
        
        let desiredAfterCount = chunkSize * 2 + (chunkSize - leadingSpaces - query.count)
        let afterStr = String(String(excerpt[range.upperBound...]).prefix(desiredAfterCount))
        let paddedAfter = afterStr + String(repeating: " ", count: max(0, desiredAfterCount - afterStr.count))
        
        return (paddedBefore, paddedAfter)
    }

    private var bestMatch: BestPiMatch? {
        model.bestMatch
    }
}

private struct HeroCard: View {
    let before: String
    let match: String
    let after: String
    let format: DateFormatOption
    let date: Date

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                digitLine(
                    line: line,
                    highlighted: index == highlightedLineIndex
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.15),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var lines: [String] {
        let leading = before + match + after
        let chunkSize = 12
        var output: [String] = []
        var index = leading.startIndex

        while index < leading.endIndex {
            let end = leading.index(index, offsetBy: chunkSize, limitedBy: leading.endIndex) ?? leading.endIndex
            output.append(String(leading[index..<end]))
            index = end
        }

        return output
    }

    private var highlightedLineIndex: Int {
        return before.count / 12
    }

    @ViewBuilder
    private func digitLine(line: String, highlighted: Bool) -> some View {
        Group {
            if highlighted {
                let leadingCount = before.count % 12
                let leading = String(line.prefix(leadingCount))
                let trailingCapacity = max(0, line.count - leadingCount - match.count)
                let trailing = String(line.suffix(trailingCapacity))

                HStack(spacing: 0) {
                    Text(leading)
                        .foregroundStyle(PiPalette.mutedInk)

                    let parts = format.queryParts(from: match, date: date)
                    Text(parts.day).foregroundStyle(PiPalette.day)
                    Text(parts.month).foregroundStyle(PiPalette.month)
                    Text(parts.year).foregroundStyle(PiPalette.year)

                    Text(trailing)
                        .foregroundStyle(PiPalette.mutedInk)
                }
            } else {
                Text(line)
                    .foregroundStyle(PiPalette.mutedInk)
            }
        }
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }

}

private struct WatchDetailView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.displayedDate)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PiPalette.logoInk)

                VStack(alignment: .leading, spacing: 8) {
                    QueryBadge(query: model.primaryQuery, format: model.primaryFormat)

                    Text(model.statusText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(model.errorMessage == nil ? PiPalette.logoInk : PiPalette.error)

                    if let bestMatch = model.bestMatch {
                        Text(bestMatch.excerpt)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(PiPalette.mutedInk)
                            .lineLimit(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(detailBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        model.step(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button("Today") {
                        model.jumpToToday()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PiPalette.day)

                    Button {
                        model.step(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .containerBackground(PiPalette.background, for: .navigation)
        .navigationTitle("Today in Pi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.white.opacity(0.88), Color.white.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct QueryBadge: View {
    let query: String
    let format: DateFormatOption

    var body: some View {
        let parts = format.queryParts(from: query)

        HStack(spacing: 0) {
            Text(parts.day).foregroundStyle(PiPalette.day)
            Text(parts.month).foregroundStyle(PiPalette.month)
            Text(parts.year).foregroundStyle(PiPalette.year)
        }
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
}
