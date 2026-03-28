import SwiftUI

struct StatsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            ScrollView {
                if let stats = viewModel.piStats {
                    VStack(spacing: 24) {
                        personalSection(stats: stats, palette: palette)
                        hallOfFameSection(stats: stats, palette: palette)
                        recordsSection(stats: stats, palette: palette)
                        formatLabSection(stats: stats, palette: palette)
                        odditiesSection(stats: stats, palette: palette)
                        piDaySection(stats: stats, palette: palette)
                    }
                    .padding(20)
                } else {
                    ContentUnavailableView("Loading Stats…", systemImage: "chart.bar")
                }
            }
            .navigationTitle("Nerdy Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.body.weight(.semibold))
                }
            }
            .background {
                if #available(iOS 26, *) { } else {
                    palette.background.ignoresSafeArea()
                }
            }
        }
    }

    private func personalSection(stats: PiStats, palette: ThemePalette) -> some View {
        let selectedDate = Self.fullDateFormatter.string(from: viewModel.selectedDate)
        let sortedMatches = viewModel.matchResults.compactMap { result -> (PiMatchResult, Int)? in
            guard let displayed = viewModel.displayedPosition(for: result) else { return nil }
            return (result, displayed)
        }
        .sorted { lhs, rhs in
            (lhs.0.storedPosition ?? .max) < (rhs.0.storedPosition ?? .max)
        }

        let best = sortedMatches.first
        let runnerUp = sortedMatches.dropFirst().first

        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Selected Date In Pi",
                subtitle: selectedDate,
                palette: palette
            )

            if let best {
                let percentile = percentileText(
                    for: best.0.storedPosition ?? 0,
                    among: stats.bestDatePositions
                )

                LazyVGrid(columns: statsGrid, spacing: 12) {
                    StatBadge(
                        title: "Best Hit",
                        value: "#\(best.1.formatted())",
                        detail: best.0.format.displayName,
                        palette: palette
                    )
                    StatBadge(
                        title: "Rarity",
                        value: percentile,
                        detail: "among indexed dates",
                        palette: palette
                    )
                    StatBadge(
                        title: "Formats Found",
                        value: "\(sortedMatches.count)",
                        detail: "ways this date lands",
                        palette: palette
                    )
                    StatBadge(
                        title: "Winning Margin",
                        value: marginText(best: best.0, runnerUp: runnerUp),
                        detail: runnerUp == nil ? "clean sweep" : "ahead of runner-up",
                        palette: palette
                    )
                }

                if let runnerUp {
                    NerdFactCard(
                        title: "Format Duel",
                        message: "\(best.0.format.displayName) wins for this date. The runner-up is \(runnerUp.0.format.displayName), trailing by \((runnerUp.1 - best.1).formatted()) digits.",
                        palette: palette
                    )
                }
            } else {
                NerdFactCard(
                    title: "No exact hit yet",
                    message: viewModel.isSelectedDateInRange
                        ? "This date doesn’t appear exactly in the bundled five-billion-digit index. That makes it one of the elusive ones."
                        : "This date is outside the bundled index range, so the personal leaderboard only lights up for indexed years.",
                    palette: palette
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func hallOfFameSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Hall Of Fame",
                subtitle: "The luckiest dates in the bundled index",
                palette: palette
            )

            VStack(spacing: 10) {
                ForEach(Array(stats.topEarliestDates.enumerated()), id: \.offset) { index, match in
                    RankingRow(
                        rank: index + 1,
                        title: prettyDate(match.date),
                        subtitle: match.format.displayName,
                        value: "digit \(viewModel.displayedPosition(for: match.position).formatted())",
                        palette: palette
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func recordsSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Calendar Records",
                subtitle: "Global winners, losers, and seasonal vibes",
                palette: palette
            )

            if let earliest = stats.earliestMatch {
                ExtremeRow(title: "Earliest Match", match: earliest, palette: palette, position: viewModel.displayedPosition(for: earliest.position))
            }

            if let latest = stats.latestMatch {
                ExtremeRow(title: "Deepest Match", match: latest, palette: palette, position: viewModel.displayedPosition(for: latest.position))
            }

            LazyVGrid(columns: statsGrid, spacing: 12) {
                if let luckiestMonth = stats.luckiestMonth {
                    StatBadge(
                        title: "Luckiest Month",
                        value: monthName(luckiestMonth.month),
                        detail: "avg #\(viewModel.displayedPosition(for: luckiestMonth.averagePosition).formatted())",
                        palette: palette
                    )
                }

                if let hardestMonth = stats.hardestMonth {
                    StatBadge(
                        title: "Hardest Month",
                        value: monthName(hardestMonth.month),
                        detail: "avg #\(viewModel.displayedPosition(for: hardestMonth.averagePosition).formatted())",
                        palette: palette
                    )
                }

                if let luckiestDay = stats.luckiestDayOfMonth {
                    StatBadge(
                        title: "Best Day Number",
                        value: "\(luckiestDay.day)",
                        detail: "avg #\(viewModel.displayedPosition(for: luckiestDay.averagePosition).formatted())",
                        palette: palette
                    )
                }

                if let hardestDay = stats.hardestDayOfMonth {
                    StatBadge(
                        title: "Worst Day Number",
                        value: "\(hardestDay.day)",
                        detail: "avg #\(viewModel.displayedPosition(for: hardestDay.averagePosition).formatted())",
                        palette: palette
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func formatLabSection(stats: PiStats, palette: ThemePalette) -> some View {
        let formatLeaders = stats.formatSuccessRate.sorted { $0.value < $1.value }

        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Format Lab",
                subtitle: "Which encodings get lucky, and which get wrecked",
                palette: palette
            )

            if let leader = formatLeaders.first {
                NerdFactCard(
                    title: "Overall Winner",
                    message: "\(leader.key.displayName) has the lowest average first appearance at digit \(viewModel.displayedPosition(for: Int(leader.value)).formatted()).",
                    palette: palette
                )
            }

            VStack(spacing: 12) {
                ForEach(formatLeaders, id: \.key) { format, avg in
                    MetricBarRow(
                        title: format.displayName,
                        subtitle: format.description,
                        value: viewModel.displayedPosition(for: Int(avg)),
                        maxValue: viewModel.displayedPosition(for: stats.maxDigitReached),
                        palette: palette
                    )
                }
            }

            if let upset = stats.biggestFormatUpset {
                NerdFactCard(
                    title: "Biggest Format Upset",
                    message: "\(prettyDate(upset.date)) is chaos. \(upset.bestFormat.displayName) lands at digit \(viewModel.displayedPosition(for: upset.bestPosition).formatted()), while \(upset.worstFormat.displayName) doesn’t show up until digit \(viewModel.displayedPosition(for: upset.worstPosition).formatted()). That’s a swing of \(viewModel.displayedPosition(for: upset.spread).formatted()) digits.",
                    palette: palette
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func odditiesSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Sequence Oddities",
                subtitle: "The deliciously nerdy stuff",
                palette: palette
            )

            if let longestRepeat = stats.longestRepeatRun {
                NerdFactCard(
                    title: "Longest Repeat Run",
                    message: "\(prettyDate(longestRepeat.date)) brings a run of \(longestRepeat.score) repeated digits in \(longestRepeat.query) via \(longestRepeat.format.displayName). Found at digit \(viewModel.displayedPosition(for: longestRepeat.position).formatted()).",
                    palette: palette
                )
            }

            if let mostUniqueDigits = stats.mostUniqueDigits {
                NerdFactCard(
                    title: "Most Digit Variety",
                    message: "\(prettyDate(mostUniqueDigits.date)) squeezes \(mostUniqueDigits.score) distinct digits into \(mostUniqueDigits.query). It’s the least repetitive winner in the set.",
                    palette: palette
                )
            }

            NerdFactCard(
                title: "Search Horizon",
                message: "The bundled index covers \(stats.totalDatesMatched.formatted()) dates and searches as deep as digit \(viewModel.displayedPosition(for: stats.maxDigitReached).formatted()). This page is basically a tiny museum of date-shaped coincidences.",
                palette: palette
            )
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func piDaySection(stats: PiStats, palette: ThemePalette) -> some View {
        let sortedYears = stats.piDayStats.keys.sorted()
        let bestPiDay = stats.piDayStats.min { $0.value < $1.value }

        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Pi Day Special",
                subtitle: "March 14 across the index years",
                palette: palette
            )

            if let bestPiDay {
                NerdFactCard(
                    title: "Best March 14",
                    message: "Pi Day \(bestPiDay.key) shows up earliest at digit \(viewModel.displayedPosition(for: bestPiDay.value).formatted()). Some years are simply more blessed by pi than others.",
                    palette: palette
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedYears, id: \.self) { year in
                        VStack(spacing: 4) {
                            Text("\(year)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                            Text("#\(viewModel.displayedPosition(for: stats.piDayStats[year] ?? 0).formatted())")
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(palette.paneSurfaceFill(for: colorScheme)))
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func percentileText(for position: Int, among allPositions: [Int]) -> String {
        guard !allPositions.isEmpty else { return "n/a" }
        let lowerCount = allPositions.filter { $0 <= position }.count
        let percentile = max(1, Int((Double(lowerCount) / Double(allPositions.count)) * 100))
        return "Top \(percentile)%"
    }

    private func marginText(best: PiMatchResult, runnerUp: (PiMatchResult, Int)?) -> String {
        guard let runnerUp, let bestDisplayed = viewModel.displayedPosition(for: best) else { return "solo" }
        return (runnerUp.1 - bestDisplayed).formatted()
    }

    private func prettyDate(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return isoDate
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else { return isoDate }
        return Self.fullDateFormatter.string(from: date)
    }

    private func monthName(_ month: Int) -> String {
        let names = Calendar(identifier: .gregorian).monthSymbols
        guard month >= 1, month <= names.count else { return "Month \(month)" }
        return names[month - 1]
    }

    private var statsGrid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
    }
}

private struct StatBadge: View {
    let title: String
    let value: String
    let detail: String
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.paneSurfaceFill(for: colorScheme)))
    }
}

private struct NerdFactCard: View {
    let title: String
    let message: String
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(message)
                .font(.footnote)
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.paneSurfaceFill(for: colorScheme)))
    }
}

private struct RankingRow: View {
    let rank: Int
    let title: String
    let subtitle: String
    let value: String
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.weight(.black))
                .foregroundStyle(palette.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            }

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.paneSurfaceFill(for: colorScheme)))
    }
}

private struct MetricBarRow: View {
    let title: String
    let subtitle: String
    let value: Int
    let maxValue: Int
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                }

                Spacer()

                Text("#\(value.formatted())")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.accent)
            }

            GeometryReader { geometry in
                let ratio = maxValue > 0 ? min(max(CGFloat(value) / CGFloat(maxValue), 0.03), 1.0) : 0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.paneSurfaceFill(for: colorScheme))
                    Capsule()
                        .fill(palette.accent.opacity(0.75))
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.paneSurfaceFill(for: colorScheme).opacity(0.55)))
    }
}

private struct ExtremeRow: View {
    let title: String
    let match: PiStats.ExtremeMatch
    let palette: ThemePalette
    let position: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            HStack {
                VStack(alignment: .leading) {
                    Text(match.date)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                    Text(match.format.displayName)
                        .font(.caption2)
                        .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                }
                Spacer()
                Text("digit \(position.formatted())")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.accent)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.paneSurfaceFill(for: colorScheme)))
        }
    }
}
