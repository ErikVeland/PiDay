import SwiftUI

// WHY: The pi canvas is visually complex — extracting it into its own file keeps
// MainView lean and makes the layout logic easy to iterate on.
// It reads the ViewModel from the environment rather than requiring it as a parameter,
// which avoids prop-drilling through parent views.

struct PiCanvasView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let revealSequence: Bool

    var body: some View {
        GeometryReader { geometry in
            piCanvas(in: geometry.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        // WHY accessibilityElement + ignore: the canvas is a dense field of digits
        // with no meaningful per-digit interaction. Collapsing it to a single element
        // and providing a concise label lets VoiceOver users understand the screen
        // state without being flooded by hundreds of individual characters.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pi digit canvas. \(viewModel.headerStatusText)")
        .accessibilityHint("Swipe left or right to navigate days. Tap the settings button below to open details.")
    }

    private func piCanvas(in size: CGSize) -> some View {
        let metrics = textMetrics(for: size, queryLength: viewModel.exactQuery.count)
        let palette = preferences.resolvedPalette

        return ZStack(alignment: .topLeading) {
            digitContextBody(in: size, metrics: metrics, palette: palette)
                .padding(.top, metrics.bodyTopInset)

            VStack(alignment: .leading, spacing: 0) {
                topMetadataLine(width: size.width - 16, metrics: metrics, palette: palette)
                Color.clear
                    .frame(height: metrics.blankLineHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(
            focusGlow(palette: palette)
        )
    }

    private func topMetadataLine(width: CGFloat, metrics: PiTextMetrics, palette: ThemePalette) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(piLeadDigits(count: metrics.headerDigitCount))...")
                .font(preferences.fontStyle.font(size: metrics.headerFontSize, weight: preferences.fontWeight.fontWeight))
                .foregroundStyle(palette.mutedInk.opacity(0.82))
                .lineLimit(1)

            Spacer(minLength: 8)

            if let match = viewModel.bestMatch {
                // WHY HStack decomposition: AnimatedCounterView needs its own view
                // identity so .contentTransition(.numericText) can roll the digits
                // smoothly. A plain string interpolation in Text is a static snapshot.
                HStack(spacing: 0) {
                    Text("[digit ")
                    AnimatedCounterView(target: viewModel.displayedPosition(for: match.storedPosition))
                    Text("]")
                }
                .font(preferences.fontStyle.font(size: metrics.headerFontSize, weight: preferences.fontWeight.fontWeight))
                .foregroundStyle(palette.ink.opacity(0.92))
                .fixedSize(horizontal: true, vertical: false)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(preferences.fontStyle.font(size: metrics.headerFontSize, weight: preferences.fontWeight.fontWeight))
                    .foregroundStyle(PiPalette.error)
                    .lineLimit(1)
            } else if !viewModel.isSelectedDateInRange {
                Text("[out of range]")
                    .font(preferences.fontStyle.font(size: metrics.headerFontSize, weight: preferences.fontWeight.fontWeight))
                    .foregroundStyle(palette.mutedInk)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(width: max(0, width), alignment: .leading)
        .padding(.trailing, max(80, width * 0.18))
        .padding(.leading, 8)
    }

    private func digitContextBody(in size: CGSize, metrics: PiTextMetrics, palette: ThemePalette) -> some View {
        let layout = makeBodyLayout(in: size, metrics: metrics)

        return Group {
            if preferences.theme == .matrix {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    matrixBodyText(
                        for: layout,
                        columns: metrics.columns,
                        bodyWidth: metrics.bodyWidth,
                        fontSize: metrics.bodyFontSize,
                        palette: palette,
                        date: context.date
                    )
                }
            } else {
                bodyText(for: layout, bodyWidth: metrics.bodyWidth, fontSize: metrics.bodyFontSize, palette: palette)
            }
        }
        // WHY scaleEffect before the outer frame: bodyWidth = columns * glyphWidth (including
        // a small inter-glyph buffer) is always slightly less than viewportWidth. Scaling the
        // rendered content to fill the exact viewport closes the sub-glyph gap and makes digits
        // reach both edges regardless of font style, weight, or size. The stretch is ≤ ~4%
        // and imperceptible on a dense monospaced digit grid.
        .scaleEffect(x: metrics.bodyScaleX, y: 1.0, anchor: .topLeading)
        .frame(width: metrics.viewportWidth, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.88),
                    Color.white,
                    Color.white,
                    Color.white.opacity(0.88),
                    Color.white.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func bodyText(for layout: PiBodyLayout, bodyWidth: CGFloat, fontSize: CGFloat, palette: ThemePalette) -> some View {
        composedBodyText(from: layout, palette: palette)
            .font(preferences.fontStyle.font(size: fontSize, weight: preferences.fontWeight.fontWeight))
            .lineSpacing(fontSize * 0.34)
            // WHY leading: SwiftUI TextAlignment has no .justified case — that
            // alignment is UIKit-only. Ragged-right reads well for all three font
            // styles on a digit canvas; the serif character will come from the
            // typeface itself, not the paragraph edge.
            .multilineTextAlignment(.leading)
            .allowsHitTesting(false)
            .frame(width: bodyWidth, alignment: .leading)
            .scaleEffect(revealSequence ? 1.0 : 0.94, anchor: .center)
            .animation(
                reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.76),
                value: revealSequence
            )
    }

    // WHY per-character rendering for Matrix: column-based cascade (each column of
    // digits drops independently from above) mirrors the Matrix code-rain aesthetic.
    // Text concatenation only supports per-line animation; individual Text views let
    // each character carry its own spring delay and ongoing phosphor rain brightness.
    private func matrixBodyText(for layout: PiBodyLayout, columns: Int, bodyWidth: CGFloat, fontSize: CGFloat, palette: ThemePalette, date: Date) -> some View {
        let time = date.timeIntervalSinceReferenceDate
        let lineSpacing = fontSize * 0.34
        let rows = layout.lines.count

        return VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(layout.lines.enumerated()), id: \.offset) { rowIdx, line in
                HStack(spacing: 0) {
                    ForEach(matrixCharData(for: line, palette: palette)) { item in
                        matrixChar(
                            item.char, color: item.color, isHighlighted: item.isHighlighted,
                            row: rowIdx, col: item.id,
                            totalRows: rows, totalCols: columns,
                            fontSize: fontSize, time: time
                        )
                    }
                }
            }
        }
        .font(.system(size: fontSize, weight: preferences.fontWeight.fontWeight, design: .monospaced))
        .allowsHitTesting(false)
        .frame(width: bodyWidth, alignment: .leading)
    }

    private func matrixCharData(for line: PiContextLine, palette: ThemePalette) -> [MatrixCharItem] {
        var items: [MatrixCharItem] = []
        var col = 0
        let ambientGreen = Color(red: 0.30, green: 0.86, blue: 0.42)
        let accentGreen = Color(red: 0.52, green: 1.00, blue: 0.64)
        let headGreen = Color(red: 0.82, green: 1.00, blue: 0.88)
        func add(_ str: String, _ clr: Color, _ highlighted: Bool) {
            for ch in str {
                items.append(MatrixCharItem(id: col, char: ch, color: clr, isHighlighted: highlighted))
                col += 1
            }
        }
        add(line.before, ambientGreen.opacity(0.72), false)
        if line.isHighlighted {
            add(line.day,   accentGreen, true)
            add(line.month, headGreen,   true)
            add(line.year,  accentGreen.opacity(0.94), true)
        }
        add(line.after, ambientGreen.opacity(0.72), false)
        return items
    }

    private func matrixChar(
        _ char: Character,
        color: Color,
        isHighlighted: Bool,
        row: Int, col: Int,
        totalRows: Int, totalCols: Int,
        fontSize: CGFloat,
        time: TimeInterval
    ) -> some View {
        // Use stream-style timing so glyphs travel as coherent top-down rain
        // rather than all columns pulsing with the same cadence.
        let baseSeed = matrixNoise(col, row)
        let columnSeed = matrixColumnNoise(col)
        let streakSeed = matrixNoise(col * 7 + row * 3, row * 11 + col)

        let cascadeDelay = reduceMotion
            ? 0.0
            : (Double(col) / Double(max(1, totalCols)) * 0.42)
            + columnSeed * 0.22
            + Double(row) * (0.001 + columnSeed * 0.003)

        let streamDuration = 4.4 + columnSeed * 3.4 + Double((col + row) % 4) * 0.22
        let cycleOffset = baseSeed * streamDuration
        let phase = ((time + cycleOffset).truncatingRemainder(dividingBy: streamDuration)) / streamDuration
        let easedPhase = phase * phase * (3.0 - 2.0 * phase)
        let spawnRows = 5.0 + columnSeed * 8.0
        let trailRows = (isHighlighted ? 9.0 : 13.0) + streakSeed * 7.0
        let headTravel = Double(totalRows) + spawnRows + trailRows
        let headPos = easedPhase * headTravel - spawnRows
        let dist = headPos - Double(row)
        let arrivalWindow = 2.2 + columnSeed * 2.8
        let arrivalProgress = max(0.0, min(1.0, (dist + arrivalWindow) / arrivalWindow))
        let glideOffsetY = CGFloat((1.0 - arrivalProgress) * (1.0 - arrivalProgress)) * fontSize * CGFloat(1.7 + columnSeed * 3.2)
        let trailProgress = max(0.0, min(1.0, 1.0 - (dist / trailRows)))
        let trailLen = trailRows
        let brightness: Double
        let glowRadius: CGFloat

        if dist > -0.4 && dist <= 0.2 {
            brightness = isHighlighted ? 2.2 : 1.85 + columnSeed * 0.40
            glowRadius = isHighlighted ? 16 : CGFloat(10 + columnSeed * 7)
        } else if dist > 0.2 && dist < trailLen {
            let t = (dist - 0.2) / (trailLen - 0.2)
            let phosphorDecay = pow(1.0 - t, isHighlighted ? 0.42 : 0.55)
            brightness = (isHighlighted ? 1.45 : 1.08 + columnSeed * 0.18) * phosphorDecay
            glowRadius = CGFloat(max(0, phosphorDecay * (isHighlighted ? 11.0 : (5.0 + columnSeed * 4.5))))
        } else {
            let flickerRate = 0.9 + columnSeed * 1.8
            let flicker = (sin(time * flickerRate + baseSeed * 9.0 + Double(row) * (0.21 + columnSeed * 0.12)) + 1) * 0.5
            brightness = isHighlighted
                ? 0.58 + flicker * 0.16
                : 0.14 + flicker * (0.06 + streakSeed * 0.03)
            glowRadius = isHighlighted ? CGFloat(flicker * 5.2) : CGFloat(flicker * (1.6 + columnSeed * 2.0))
        }

        let dropHeight = fontSize * CGFloat(spawnRows * 0.42)
        let lateralJitter = isHighlighted
            ? 0
            : CGFloat((matrixNoise(col * 13, row * 5) - 0.5) * 0.20)
        let headWindow = dist > -0.18 && dist < trailLen * 0.28
        let displayedChar = matrixDisplayedCharacter(
            base: char,
            isHighlighted: isHighlighted,
            row: row,
            col: col,
            time: time,
            shouldMutate: headWindow
        )

        let phosphorColor = isHighlighted
            ? color.opacity(0.96)
            : color.opacity(min(0.90, 0.18 + trailProgress * 0.70))
        let trailGhostOpacity = max(0.0, min(0.78, trailProgress * (isHighlighted ? 0.50 : 0.72)))
        let farGhostOpacity = max(0.0, min(0.48, trailProgress * (isHighlighted ? 0.28 : 0.40)))
        let verticalSettledOffset = revealSequence ? -glideOffsetY : -dropHeight
        let nearGhostOffset = verticalSettledOffset - fontSize * CGFloat(0.42 + columnSeed * 0.26)
        let midGhostOffset = verticalSettledOffset - fontSize * CGFloat(0.82 + streakSeed * 0.34)
        let farGhostOffset = verticalSettledOffset - fontSize * CGFloat(1.24 + streakSeed * 0.52)
        let leadBloomOpacity = max(0.0, min(0.68, (brightness - 0.7) * 0.48))
        let wakeOpacity = max(0.0, min(0.22, trailProgress * 0.18))

        return ZStack {
            Text(String(displayedChar))
                .foregroundStyle(phosphorColor.opacity(wakeOpacity))
                .blur(radius: 3.2)
                .shadow(color: phosphorColor.opacity(wakeOpacity), radius: glowRadius * 2.1)
                .offset(x: lateralJitter, y: farGhostOffset - fontSize * 0.55)

            Text(String(displayedChar))
                .foregroundStyle(phosphorColor.opacity(farGhostOpacity))
                .blur(radius: isHighlighted ? 1.7 : 2.3)
                .shadow(color: phosphorColor.opacity(farGhostOpacity * 0.85), radius: glowRadius * 1.8)
                .offset(x: lateralJitter, y: farGhostOffset)

            Text(String(displayedChar))
                .foregroundStyle(phosphorColor.opacity(trailGhostOpacity * 0.7))
                .blur(radius: isHighlighted ? 1.0 : 1.5)
                .shadow(color: phosphorColor.opacity(trailGhostOpacity * 0.72), radius: glowRadius * 1.35)
                .offset(x: lateralJitter, y: midGhostOffset)

            Text(String(displayedChar))
                .foregroundStyle(phosphorColor.opacity(trailGhostOpacity))
                .blur(radius: isHighlighted ? 0.8 : 1.2)
                .shadow(color: phosphorColor.opacity(trailGhostOpacity), radius: glowRadius * 1.15)
                .offset(x: lateralJitter, y: nearGhostOffset)

            Text(String(displayedChar))
                .foregroundStyle(Color.white.opacity(leadBloomOpacity))
                .blur(radius: glowRadius * 0.16)
                .offset(x: lateralJitter, y: verticalSettledOffset)

            Text(String(displayedChar))
                .foregroundStyle(color.opacity(min(brightness, 1.0)))
                .brightness(max(0, brightness - 1.0) * 0.55)
                .shadow(color: color.opacity(min(brightness * 0.80, 0.98)), radius: glowRadius)
                .offset(x: lateralJitter, y: verticalSettledOffset)
        }
        .opacity(revealSequence ? 1 : 0)
        .animation(
            reduceMotion
                ? .none
                : .spring(response: 0.30, dampingFraction: 0.70).delay(cascadeDelay),
            value: revealSequence
        )
    }

    private func composedBodyText(from layout: PiBodyLayout, palette: ThemePalette) -> Text {
        layout.lines.enumerated().reduce(Text("")) { partial, pair in
            let (index, line) = pair
            let newline = index == 0 ? Text("") : Text("\n")

            if line.isHighlighted {
                return partial
                + newline
                + Text(line.before).foregroundStyle(palette.mutedInk.opacity(0.62))
                + Text(line.day).foregroundStyle(palette.day.opacity(revealSequence ? 1 : 0.18))
                + Text(line.month).foregroundStyle(palette.month.opacity(revealSequence ? 1 : 0.18))
                + Text(line.year).foregroundStyle(palette.year.opacity(revealSequence ? 1 : 0.18))
                + Text(line.after).foregroundStyle(palette.mutedInk.opacity(0.62))
            }

            return partial
            + newline
            + Text(line.before).foregroundStyle(palette.mutedInk.opacity(0.62))
        }
    }

    // MARK: - Layout computation

    private func textMetrics(for size: CGSize, queryLength: Int) -> PiTextMetrics {
        let usableWidth = max(180, size.width)
        let preferredBodySize = preferences.digitSize.canvasFontSize
        let maxBodySize = max(22, usableWidth * 0.11)
        let bodyFontSize = max(15, min(preferredBodySize, maxBodySize))
        let lineHeight = bodyFontSize * 1.48
        let blankLineHeight = lineHeight

        // WHY compute rows from full height first: we need queryRow before we can
        // derive the ideal bodyTopInset, but rows depends on bodyTopInset. Breaking
        // the cycle: compute a preliminary row count from the full canvas height,
        // derive queryRow and the ideal top inset, then re-derive the final row count.
        let fullHeightRows = max(8, Int(size.height / lineHeight))
        let queryRow = fullHeightRows / 2

        // Place the middle row's vertical center at the canvas center.
        // WHY max(0, ...): for very large font sizes the ideal inset goes negative
        // (the date center would need to be above the canvas top). Clamp to zero
        // so we don't push content above the safe area; the date will be slightly
        // below center in those cases, which is imperceptible at large sizes.
        let desiredBodyTopInset = size.height / 2 - CGFloat(queryRow) * lineHeight - lineHeight / 2
        let bodyTopInset = max(0, desiredBodyTopInset)

        let rows = max(8, Int((size.height - bodyTopInset) / lineHeight))
        let glyphWidth = max(1, measuredGlyphWidth(for: bodyFontSize) + 0.8)
        let viewportWidth = max(120, floor(usableWidth))
        let rawColumns = max(max(queryLength + 8, 16), Int(floor(viewportWidth / glyphWidth)))
        let columns = alignedColumnCount(rawColumns, queryLength: queryLength)
        let bodyWidth = CGFloat(columns) * glyphWidth
        // Scale factor that closes the sub-glyph gap between bodyWidth and viewportWidth,
        // making characters fill exactly edge-to-edge regardless of font weight or size.
        let bodyScaleX = bodyWidth > 0 ? viewportWidth / bodyWidth : 1.0

        return PiTextMetrics(
            bodyFontSize: bodyFontSize,
            headerFontSize: max(12, bodyFontSize * 0.55),
            lineHeight: lineHeight,
            bodyTopInset: bodyTopInset,
            blankLineHeight: blankLineHeight,
            rows: rows,
            queryRow: min(queryRow, rows - 1),
            columns: columns,
            headerDigitCount: max(12, columns - 10),
            glyphWidth: glyphWidth,
            bodyWidth: bodyWidth,
            bodyScaleX: bodyScaleX,
            viewportWidth: viewportWidth
        )
    }

    private func makeBodyLayout(in size: CGSize, metrics: PiTextMetrics) -> PiBodyLayout {
        let query = viewModel.exactQuery
        let totalCharacters = metrics.rows * metrics.columns
        let queryRow = metrics.queryRow
        let queryColumn = centeredQueryColumn(totalColumns: metrics.columns, queryLength: query.count)
        let targetStart = queryRow * metrics.columns + queryColumn
        let context = exactContextSource(totalCharacters: totalCharacters, targetStart: targetStart, query: query)
        let characters = Array(context.visibleText)

        var lines: [PiContextLine] = []
        lines.reserveCapacity(metrics.rows)
        let highlightRow = context.highlightStart / metrics.columns
        let highlightColumn = context.highlightStart % metrics.columns

        for row in 0..<metrics.rows {
            let rowStart = row * metrics.columns
            let rowEnd = rowStart + metrics.columns
            let line = String(characters[rowStart..<rowEnd])

            if row == highlightRow, !query.isEmpty, highlightColumn + query.count <= line.count {
                let before = String(line.prefix(highlightColumn))
                let parts = highlightedParts(for: query, format: viewModel.activeFormat)
                let afterStart = line.index(line.startIndex, offsetBy: highlightColumn + query.count)
                let after = String(line[afterStart...])
                lines.append(PiContextLine(
                    before: before, day: parts.day, month: parts.month,
                    year: parts.year, after: after, isHighlighted: true
                ))
            } else {
                lines.append(PiContextLine(
                    before: line, day: "", month: "", year: "", after: "", isHighlighted: false
                ))
            }
        }

        return PiBodyLayout(lines: lines, highlightedStart: context.highlightStart)
    }

    private func exactContextSource(totalCharacters: Int, targetStart: Int, query: String) -> (visibleText: String, highlightStart: Int) {
        guard let match = viewModel.bestMatch else {
            let fallback = String(repeating: query, count: max(8, totalCharacters / max(1, query.count) + 6))
            let visible = String(fallback.prefix(totalCharacters))
            return (visible, min(targetStart, max(0, visible.count - query.count)))
        }

        let excerpt = match.excerpt
        let queryOffset = min(viewModel.excerptRadius, max(0, match.storedPosition - 1))
        let clampedQueryOffset = min(queryOffset, max(0, excerpt.count - query.count))
        let queryStart = excerpt.index(excerpt.startIndex, offsetBy: clampedQueryOffset)
        let queryEnd = excerpt.index(queryStart, offsetBy: min(query.count, excerpt.count - clampedQueryOffset))

        let maxBeforeCount = min(clampedQueryOffset, targetStart)
        let afterCapacity = max(0, totalCharacters - targetStart - query.count)
        let availableAfterCount = min(excerpt.distance(from: queryEnd, to: excerpt.endIndex), afterCapacity)

        let beforeVisibleStart = excerpt.index(queryStart, offsetBy: -maxBeforeCount)
        let before = String(excerpt[beforeVisibleStart..<queryStart])
        let matched = String(excerpt[queryStart..<queryEnd])
        let afterVisibleEnd = excerpt.index(queryEnd, offsetBy: availableAfterCount)
        let after = String(excerpt[queryEnd..<afterVisibleEnd])

        let leftPadding = max(0, targetStart - before.count)
        var visible = String(repeating: " ", count: leftPadding) + before + matched + after

        if visible.count < totalCharacters {
            visible += String(repeating: " ", count: totalCharacters - visible.count)
        } else if visible.count > totalCharacters {
            visible = String(visible.prefix(totalCharacters))
        }

        return (visible, targetStart)
    }

    // Delegates to DateFormatOption.queryParts — single source of truth.
    private func highlightedParts(for query: String, format: DateFormatOption) -> (day: String, month: String, year: String) {
        format.queryParts(from: query)
    }

    // MARK: - Helpers

    // WHY private static let: this string never changes. Recomputing it on every
    // body evaluation (which can happen many times per second during scrolling) wastes
    // CPU and allocates a new String instance each time. Hoisting it as a static
    // constant means exactly one allocation for the lifetime of the app.
    private static let piBase = "3.141592653589793238462643383279502884197169399375105820974944592"

    private func piLeadDigits(count: Int) -> String {
        let base = Self.piBase
        if count <= base.count { return String(base.prefix(count)) }
        let remainder = count - base.count
        let padding = String(repeating: "31415926", count: max(1, remainder / 8 + 1))
        return base + String(padding.prefix(remainder))
    }

    private func formattedPosition(_ storedPosition: Int) -> String {
        viewModel.displayedPosition(for: storedPosition).formatted(.number.grouping(.automatic))
    }

    private func measuredGlyphWidth(for fontSize: CGFloat) -> CGFloat {
        let uiFont = preferences.fontStyle.uiFont(size: fontSize, weight: preferences.fontWeight.fontWeight)
        let sample = "0" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: uiFont]
        return ceil(sample.size(withAttributes: attributes).width)
    }

    private func centeredQueryColumn(totalColumns: Int, queryLength: Int) -> Int {
        guard totalColumns > 0, queryLength > 0 else { return 0 }
        let canvasCenter = Double(totalColumns - 1) / 2.0
        let queryCenter = Double(queryLength - 1) / 2.0
        return max(0, min(totalColumns - queryLength, Int(round(canvasCenter - queryCenter))))
    }

    private func alignedColumnCount(_ rawColumns: Int, queryLength: Int) -> Int {
        let minimumColumns = max(queryLength + 6, 16)
        guard rawColumns > minimumColumns else { return minimumColumns }
        let parityMatches = rawColumns % 2 == queryLength % 2
        if parityMatches {
            return rawColumns
        }
        return max(minimumColumns, rawColumns - 1)
    }

    private func focusGlow(palette: ThemePalette) -> some View {
        Group {
            if preferences.theme == .matrix {
                RadialGradient(
                    colors: [
                        palette.accent.opacity(0.0),
                        palette.accent.opacity(0.12),
                        palette.accent.opacity(0.30),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 18,
                    endRadius: 480
                )
                .blendMode(.screen)
                .ignoresSafeArea()
            } else {
                PiPalette.focusGlow
                    .blendMode(.screen)
                    .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }

    private func matrixNoise(_ a: Int, _ b: Int) -> Double {
        let value = sin(Double(a) * 12.9898 + Double(b) * 78.233 + 43.531)
        return value - floor(value)
    }

    private func matrixColumnNoise(_ col: Int) -> Double {
        matrixNoise(col * 17 + 3, col * 29 + 11)
    }

    private func matrixDisplayedCharacter(
        base: Character,
        isHighlighted: Bool,
        row: Int,
        col: Int,
        time: TimeInterval,
        shouldMutate: Bool
    ) -> Character {
        guard !isHighlighted, shouldMutate, !reduceMotion else { return base }

        let glyphs = Array("0123456789+-*/=<>{}[]()#$%&@")
        let tick = Int((time * (7.5 + matrixColumnNoise(col) * 8.0)).rounded(.down))
        let index = abs((tick + row * 7 + col * 13) % glyphs.count)
        let mutationChance = matrixNoise(tick + col * 5, row * 19 + col)

        if mutationChance > 0.44 {
            return glyphs[index]
        }

        return base
    }
}

// MARK: - Layout types (private to this feature)

// Per-character data for Matrix rain rendering.
// id == column index, unique within each row's ForEach.
private struct MatrixCharItem: Identifiable {
    let id: Int
    let char: Character
    let color: Color
    let isHighlighted: Bool
}

// ── AnimatedCounterView ───────────────────────────────────────────────────────
// Rolls a number from its previous value to `target` using iOS 16+
// .contentTransition(.numericText), which animates each digit like a slot machine.
// Respects accessibilityReduceMotion — snaps instantly with no animation.
// Defined at module scope (not private) so DetailSheetView can reuse it.
struct AnimatedCounterView: View {
    let target: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Int = 0

    var body: some View {
        Text(displayed, format: .number)
            .contentTransition(.numericText(countsDown: false))
            .task(id: target) {
                guard !reduceMotion else { displayed = target; return }
                // Animate from wherever we currently are → target.
                // First appearance: displayed starts at 0 so it counts up from zero.
                // Subsequent changes: digits roll directly from old number to new one.
                withAnimation(.easeOut(duration: 1.5)) {
                    displayed = target
                }
            }
    }
}

private struct PiTextMetrics {
    let bodyFontSize: CGFloat
    let headerFontSize: CGFloat
    let lineHeight: CGFloat
    let bodyTopInset: CGFloat
    let blankLineHeight: CGFloat
    let rows: Int
    let queryRow: Int
    let columns: Int
    let headerDigitCount: Int
    let glyphWidth: CGFloat
    let bodyWidth: CGFloat
    let bodyScaleX: CGFloat
    let viewportWidth: CGFloat
}

private struct PiBodyLayout {
    let lines: [PiContextLine]
    let highlightedStart: Int
}

private struct PiContextLine {
    let before: String
    let day: String
    let month: String
    let year: String
    let after: String
    let isHighlighted: Bool
}
