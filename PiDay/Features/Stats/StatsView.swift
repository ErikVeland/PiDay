import SwiftUI

struct StatsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            ScrollView {
                if let stats = viewModel.piStats {
                    VStack(spacing: 24) {
                        overviewSection(stats: stats, palette: palette)
                        extremesSection(stats: stats, palette: palette)
                        formatBattleSection(stats: stats, palette: palette)
                        piDayTriviaSection(stats: stats, palette: palette)
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

    private func overviewSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Index Overview")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            HStack(spacing: 12) {
                StatBadge(title: "Dates Matched", value: "\(stats.totalDatesMatched)", palette: palette)
                StatBadge(title: "Avg Position", value: "\(stats.averagePosition)", palette: palette)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Search Horizon")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                Text("We've searched up to digit \(stats.maxDigitReached.formatted()) to ensure 100% coverage for the next decade.")
                    .font(.footnote)
                    .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func extremesSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Absolute Extremes")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            if let earliest = stats.earliestMatch {
                ExtremeRow(title: "Earliest Match", match: earliest, palette: palette)
            }

            if let latest = stats.latestMatch {
                ExtremeRow(title: "Deepest Match", match: latest, palette: palette)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func formatBattleSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Format Face-off")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            Text("Which date format appears earliest on average?")
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            VStack(spacing: 12) {
                ForEach(DateFormatOption.allCases) { format in
                    if let avg = stats.formatSuccessRate[format] {
                        HStack {
                            Text(format.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
                            Spacer()
                            Text("\(Int(avg).formatted())")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28, palette: palette)
    }

    private func piDayTriviaSection(stats: PiStats, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pi Day Special")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))

            Text("How early does March 14th appear each year?")
                .font(.subheadline)
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stats.piDayStats.keys.sorted(), id: \.self) { year in
                        VStack(spacing: 4) {
                            Text("\(year)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
                            Text("\(stats.piDayStats[year]?.formatted() ?? "-")")
                                .font(.footnote.weight(.semibold))
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
}

private struct StatBadge: View {
    let title: String
    let value: String
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.paneSecondaryText(for: colorScheme))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.panePrimaryText(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.paneSurfaceFill(for: colorScheme)))
    }
}

private struct ExtremeRow: View {
    let title: String
    let match: PiStats.ExtremeMatch
    let palette: ThemePalette
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
                Text("digit \(match.position.formatted())")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.accent)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.paneSurfaceFill(for: colorScheme)))
        }
    }
}
