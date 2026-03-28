import SwiftUI
import UniformTypeIdentifiers

// MARK: - Render error

private struct ShareCardRenderError: LocalizedError {
    var errorDescription: String? {
        "Unable to generate the share card. Please try again."
    }
}

// MARK: - Transferable wrapper

// WHY a custom Transferable instead of sharing plain text:
// `ShareLink(item: someString)` gives the receiver plain text.
// `ShareLink(item: ShareableCard(...))` gives the receiver a PNG image —
// the kind of thing people actually post to Instagram or iMessage.
//
// The Transferable protocol bridges our SwiftUI view into the system share sheet.
// `DataRepresentation` says "when the receiver wants a PNG, render it for them."
struct ShareableCard: Transferable {
    let style: ShareCardStyle
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
            style: style,
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
        // WHY throw instead of returning Data(): returning empty Data() causes
        // the share sheet to open with a broken/invisible attachment and no
        // error message. Throwing fails the transfer cleanly and iOS surfaces
        // an alert to the user, which is far better than silent corruption.
        DataRepresentation(exportedContentType: .png) { card in
            let image = await MainActor.run { card.render() }
            guard let data = image?.pngData() else {
                throw ShareCardRenderError()
            }
            return data
        }
    }
}

// MARK: - Card view

// WHY no @Environment here: this view is rendered by ImageRenderer outside the
// normal SwiftUI view hierarchy. @Environment values (like AppViewModel) are not
// available in that context. All data must come through the initializer.
struct ShareCardView: View {
    let style: ShareCardStyle
    let date: Date
    let bestMatch: BestPiMatch?
    let query: String
    let format: DateFormatOption
    let displayedPosition: Int?
    let excerptRadius: Int
    let palette: ThemePalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
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

                if style == .nerd {
                    nerdStatsSection
                        .padding(.top, 18)
                }

                Spacer()

                // Footer
                Text("Find your date in π")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle((palette.mutedInk.opacity(0.5) as Color))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .classic, .battle:
            palette.background
        case .nerd:
            LinearGradient(
                colors: [
                    palette.background,
                    (palette.accent.opacity(0.18) as Color),
                    palette.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                .foregroundStyle((palette.mutedInk.opacity(0.7) as Color))
                .padding(.bottom, 8)

            // Excerpt strip — shows the actual pi digits around the match
            excerptLine(match: match)
        }
    }

    private var nerdStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nerd Facts")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.mutedInk)

            HStack(spacing: 10) {
                nerdChip(title: "Format", value: format.displayName)
                nerdChip(title: "Query", value: query)
            }

            if let funFact = PiDelightCopy.detailFact(for: date, bestMatch: bestMatch) {
                Text(funFact)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.mutedInk)
            }
        }
    }

    private var notFoundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(query)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle((palette.mutedInk.opacity(0.35) as Color))

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
        .foregroundStyle((palette.ink.opacity(0.8) as Color))
    }

    private func coloredQueryText(_ query: String, format: DateFormatOption) -> Text {
        let parts = format.queryParts(from: query, date: date)
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

        let parts = format.queryParts(from: match.query, date: date)
        return (
            Text(result.before).foregroundStyle((palette.mutedInk.opacity(0.45) as Color))
            + Text(parts.day).foregroundStyle(palette.day)
            + Text(parts.month).foregroundStyle(palette.month)
            + Text(parts.year).foregroundStyle(palette.year)
            + Text(result.after).foregroundStyle((palette.mutedInk.opacity(0.45) as Color))
        )
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
    }

    private func nerdChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle((palette.mutedInk.opacity(0.7) as Color))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((palette.ink.opacity(0.06) as Color))
        )
    }
}

struct BattleShareableCard: Transferable {
    let battle: DateBattleResult
    let palette: ThemePalette

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(
            content: BattleShareCardView(battle: battle, palette: palette)
                .frame(width: 360, height: 360)
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            let image = await MainActor.run { card.render() }
            guard let data = image?.pngData() else {
                throw ShareCardRenderError()
            }
            return data
        }
    }
}

struct BattleShareCardView: View {
    let battle: DateBattleResult
    let palette: ThemePalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.background, (palette.accent.opacity(0.2) as Color)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    shareWordmark
                    Spacer()
                    Text("DATE BATTLE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(palette.mutedInk)
                }

                contenderBlock(title: "Left date", contender: battle.left)
                contenderBlock(title: "Right date", contender: battle.right)

                Text(battle.verdict)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink)
                    .padding(.top, 4)

                Spacer()

                Text("Find your date in π")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle((palette.mutedInk.opacity(0.55) as Color))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(28)
        }
    }

    private var shareWordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: -2) {
            Text("∏")
                .font(.system(size: 16, weight: .black, design: .serif))
                .italic()
            Text("day")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle((palette.ink.opacity(0.8) as Color))
    }

    private func contenderBlock(title: String, contender: DateBattleContender) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(palette.mutedInk)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(contender.date.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.ink)

                    if let position = contender.displayedPosition,
                       let match = contender.bestMatch {
                        Text("\(match.format.displayName) at digit \(position.formatted())")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(palette.accent)
                        Text(contender.percentileLabel)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.mutedInk)
                    } else {
                        Text("No exact hit")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.mutedInk)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((palette.ink.opacity(0.06) as Color))
            )
        }
    }
}

struct ShareOptionsSheet: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let classicCard: ShareableCard
    let nerdCard: ShareableCard

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            List {
                Section("Share Styles") {
                    ShareLink(item: classicCard, preview: SharePreview("PiDay", image: Image(systemName: "square.and.arrow.up"))) {
                        shareRow(
                            title: "Classic",
                            subtitle: date.formatted(.dateTime.day().month(.wide).year()),
                            symbol: "square.and.arrow.up",
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: nerdCard, preview: SharePreview("PiDay Nerd", image: Image(systemName: "chart.bar.xaxis"))) {
                        shareRow(
                            title: "Nerd",
                            subtitle: "Adds format and fun-fact flavor",
                            symbol: "chart.bar.xaxis",
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    private func shareRow(title: String, subtitle: String, symbol: String, palette: ThemePalette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
                .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.mutedInk)
            }
        }
    }
}

struct DateBattleView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let anchorDate: Date
    let initialOpponent: Date?

    @State private var opponentDate: Date
    @State private var battle: DateBattleResult?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var latestRequestID = UUID()

    init(anchorDate: Date, initialOpponent: Date? = nil) {
        self.anchorDate = anchorDate
        self.initialOpponent = initialOpponent
        _opponentDate = State(initialValue: initialOpponent ?? Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate)
    }

    var body: some View {
        let palette = preferences.resolvedPalette

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    controlsCard(palette: palette)

                    if isLoading && battle == nil {
                        ProgressView("Comparing dates…")
                            .tint(palette.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else if let battle {
                        battleSummaryCard(battle: battle, palette: palette)
                        contenderCard(title: "Selected date", contender: battle.left, palette: palette)
                        contenderCard(title: "Challenger", contender: battle.right, palette: palette)
                        shareBattleCard(battle: battle, palette: palette)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Date Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                scheduleBattleRefresh()
            }
            .onChange(of: opponentDate) { _, _ in
                scheduleBattleRefresh()
            }
            .onDisappear {
                refreshTask?.cancel()
            }
        }
    }

    private func controlsCard(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pit the selected date against any rival. Pi will choose only one.")
                .font(.subheadline)
                .foregroundStyle(palette.mutedInk)

            VStack(alignment: .leading, spacing: 6) {
                Text("Selected date")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.mutedInk)
                Text(anchorDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.ink)
            }

            DatePicker("Challenger", selection: $opponentDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(palette.accent)
        }
        .padding(16)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func battleSummaryCard(battle: DateBattleResult, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verdict")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.mutedInk)

            Text(battle.verdict)
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.ink)

            if let margin = battle.winningMargin, battle.hasWinner {
                Text("Winning margin: \(margin.formatted()) digits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func contenderCard(title: String, contender: DateBattleContender, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.mutedInk)

            Text(contender.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.ink)

            if let match = contender.bestMatch, let position = contender.displayedPosition {
                HStack(spacing: 10) {
                    infoChip(title: "Digit", value: "#\(position.formatted())", palette: palette)
                    infoChip(title: "Format", value: match.format.displayName, palette: palette)
                    infoChip(title: "Rarity", value: contender.percentileLabel, palette: palette)
                }
                Text(match.query)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(palette.ink)
            } else if let error = contender.summary.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(PiPalette.error)
            } else {
                Text("No exact hit in the active search formats.")
                    .font(.subheadline)
                    .foregroundStyle(palette.mutedInk)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func shareBattleCard(battle: DateBattleResult, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share the smackdown")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.ink)

            ShareLink(
                item: BattleShareableCard(battle: battle, palette: palette),
                preview: SharePreview("PiDay Battle", image: Image(systemName: "bolt.shield"))
            ) {
                Label("Share battle card", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
        }
        .padding(16)
        .glassCard(cornerRadius: 20, palette: palette)
    }

    private func infoChip(title: String, value: String, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.mutedInk)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.paneSurfaceFill(for: colorScheme)))
    }

    private func scheduleBattleRefresh() {
        refreshTask?.cancel()
        let requestID = UUID()
        latestRequestID = requestID
        refreshTask = Task {
            await refreshBattle(requestID: requestID)
        }
    }

    private func refreshBattle(requestID: UUID) async {
        isLoading = true
        let leftDate = Calendar(identifier: .gregorian).startOfDay(for: anchorDate)
        let rightDate = Calendar(identifier: .gregorian).startOfDay(for: opponentDate)
        async let leftSummary = viewModel.repositorySummary(for: leftDate)
        async let rightSummary = viewModel.repositorySummary(for: rightDate)
        let result = await viewModel.compareDates(
            leftDate: leftDate,
            leftSummary: leftSummary,
            rightDate: rightDate,
            rightSummary: rightSummary
        )
        guard !Task.isCancelled, latestRequestID == requestID else { return }
        battle = result
        isLoading = false
    }
}
