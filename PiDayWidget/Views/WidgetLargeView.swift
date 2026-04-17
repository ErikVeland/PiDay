import SwiftUI
import WidgetKit

struct WidgetLargeView: View {
    let entry: PiDayEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            Divider().opacity(0.1)

            HStack(alignment: .top, spacing: 20) {
                todayMainSection
                Spacer()
                statsSection
            }

            Spacer(minLength: 0)

            upcomingSection
        }
        .padding(16)
        .containerBackground(for: .widget) {
            entry.palette.background
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.wide)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(entry.palette.mutedInk)
                Text(entry.date.formatted(.dateTime.day().month()))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(entry.palette.ink)
            }
            Spacer()
            PiWordmark(symbol: entry.featuredNumber.logoSymbol, palette: entry.palette)
        }
    }

    private var todayMainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY IN \(entry.featuredNumber.heatMapSymbol)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(entry.palette.mutedInk)

            switch entry.result {
            case let .found(_, _, position, excerpt):
                VStack(alignment: .leading, spacing: 4) {
                    Text("digit \(position.formatted())")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(entry.palette.accent)

                    (Text(excerpt.before).foregroundStyle(entry.palette.ink.opacity(0.4))
                     + Text(excerpt.query).foregroundStyle(entry.palette.ink).bold()
                     + Text(excerpt.after).foregroundStyle(entry.palette.ink.opacity(0.4)))
                    .font(.system(size: 16, design: .monospaced))
                    .lineLimit(1)
                }
            case let .notFound(heroQuery, _):
                Text("\(heroQuery) not found in bundled digits")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            case .outOfRange:
                Text("Outside bundled range")
                    .font(.caption)
                    .foregroundStyle(entry.palette.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NERDY STATS")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(entry.palette.mutedInk)

            if let stats = entry.stats {
                VStack(alignment: .leading, spacing: 8) {
                    if let luckiestMonth = stats.luckiestMonth {
                        statMiniRow(title: "Luckiest Month", value: monthName(luckiestMonth.month))
                    }
                    if let topDate = stats.topEarliestDates.first {
                        statMiniRow(title: "Best Date", value: shortIso(topDate.date))
                    }
                }
            } else {
                Text("Stats loading…")
                    .font(.caption2)
                    .foregroundStyle(entry.palette.mutedInk)
            }
        }
        .frame(width: 100)
    }

    private func statMiniRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(entry.palette.mutedInk)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.palette.ink)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMING UP")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(entry.palette.mutedInk)

            HStack(spacing: 8) {
                if let upcoming = entry.upcomingResults {
                    let sortedDates = upcoming.keys.sorted()
                    ForEach(sortedDates, id: \.self) { date in
                        upcomingTile(date: date, result: upcoming[date]!)
                    }
                }
            }
        }
    }

    private func upcomingTile(date: Date, result: PiDayEntry.EntryResult) -> some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(entry.palette.mutedInk)

            VStack(spacing: 2) {
                switch result {
                case let .found(_, _, position, _):
                    Text("\(position / 1000)k")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.palette.accent)
                case .notFound, .outOfRange:
                    Text("-")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.palette.mutedInk)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(entry.palette.ink.opacity(0.05)))
        }
        .frame(maxWidth: .infinity)
    }

    private func monthName(_ month: Int) -> String {
        let names = Calendar(identifier: .gregorian).monthSymbols
        guard month >= 1, month <= names.count else { return "\(month)" }
        return names[month - 1]
    }

    private func shortIso(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3 else { return isoDate }
        return "\(parts[1])/\(parts[2])"
    }
}
