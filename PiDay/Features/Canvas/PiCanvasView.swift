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

    // WHY reference-type wrapper: both caches are mutated inside body (via
    // cachedGlyphWidth and cachedBodyLayout). Mutating a class *instance* stored
    // in @State does not change the @State value (the reference stays the same),
    // so SwiftUI never sees a "state modified during view update." Using separate
    // @State structs would trigger that warning because assigning a new struct
    // value IS a state change from SwiftUI's perspective.
    @State private var canvasCache = CanvasCache()
    // WHY track reveal start time: Canvas draws imperatively — there are no per-node
    // SwiftUI animation states. We replicate the cascade drop-in by recording when
    // revealSequence first became true, then computing each character's spring progress
    // from elapsed time in the draw closure, matching the original per-item delays.
    @State private var revealStartDate: Date? = nil

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
        // Track when the cascade reveal begins so the Canvas can compute time-based
        // spring progress for each character without per-node SwiftUI animation state.
        .onChange(of: revealSequence) { _, newValue in
            revealStartDate = newValue ? Date() : nil
        }
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
                .foregroundStyle((palette.mutedInk.opacity(0.82) as Color))
                .lineLimit(1)

            Spacer(minLength: 8)

            if let match = viewModel.bestMatch {
                // WHY format name instead of position: the result strip below already
                // shows "digit X · Cool" with an animated counter. Repeating the
                // position here creates a doubled display. The format name is more
                // useful context for the canvas itself — it tells the user *which*
                // date format is highlighted in the digit stream.
                Text("[\(match.format.displayName)]")
                    .font(preferences.fontStyle.font(size: metrics.headerFontSize, weight: preferences.fontWeight.fontWeight))
                    .foregroundStyle((palette.ink.opacity(0.92) as Color))
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
        let layout = cachedBodyLayout(in: size, metrics: metrics)

        return Group {
            if preferences.theme.isAnimated {
                // WHY charGrid is captured here, not inside the TimelineView closure:
                // matrixCharData only maps line colours — it does not depend on time.
                // Building the grid inside the Canvas draw closure allocates ~600
                // MatrixCharItem structs every 24 fps frame. Capturing it here means
                // it is rebuilt only when layout or palette actually change (date
                // navigation, preference changes), collapsing that cost to near-zero.
                let charGrid: [[MatrixCharItem]] = layout.lines.map { matrixCharData(for: $0, palette: palette) }
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    matrixBodyText(
                        for: layout,
                        charGrid: charGrid,
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
        // WHY topLeading + clipped: bodyWidth is deliberately wider than viewportWidth
        // (extra overflow columns ensure this even if the UIKit glyph measurement is
        // slightly generous). topLeading pins the first character at x = 0 so the left
        // edge is always flush; the overflow on the right is clipped, giving a clean
        // right edge. Both frames must use .topLeading — using .top on the outer frame
        // would center the viewport in the available space and produce a visible left margin.
        .frame(width: metrics.viewportWidth, alignment: .topLeading)
        .clipped()
        .opacity(isNotFound ? 0.08 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isNotFound)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mask(
            LinearGradient(
                colors: [
                    (Color.white.opacity(0.14) as Color),
                    (Color.white.opacity(0.88) as Color),
                    Color.white,
                    Color.white,
                    (Color.white.opacity(0.88) as Color),
                    (Color.white.opacity(0.18) as Color)
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

    // WHY Canvas instead of VStack/HStack/ForEach: the previous renderer created
    // ~600 SwiftUI Text nodes × 6 blur/shadow layers each = ~3,600 nodes that
    // SwiftUI must diff, layout, and rasterise every 24 fps frame. Even with
    // drawingGroup() collapsing the final composite, SwiftUI still maintains every
    // node in its view tree and issues one GPU render-to-texture per blur call.
    //
    // Canvas draws imperatively — zero view nodes, zero diffing. All ~600 characters
    // are painted in two passes inside a single GPU texture: (1) a blurred glow layer
    // where addFilter(.blur) applies ONE blur operation over every character at once,
    // then (2) a sharp pass for the crisp foreground glyphs. This collapses what was
    // ~2,400 per-character GPU blur operations down to 1 regardless of char count.
    private func matrixBodyText(for layout: PiBodyLayout, charGrid: [[MatrixCharItem]], columns: Int, bodyWidth: CGFloat, fontSize: CGFloat, palette: ThemePalette, date: Date) -> some View {
        let time = date.timeIntervalSinceReferenceDate
        let lineH  = fontSize * 1.48   // matches PiTextMetrics.lineHeight
        let rows   = layout.lines.count
        let charWidth = bodyWidth / CGFloat(max(1, columns))

        // Reveal timing: negative = not yet revealed, large = fully settled.
        // revealStartDate is set in onChange(of: revealSequence) on the parent view.
        let elapsedReveal: Double = revealSequence
            ? (revealStartDate.map { max(0, time - $0.timeIntervalSinceReferenceDate) } ?? 9_999)
            : -1

        let skipAnim = reduceMotion

        // WHY colorMode omitted (.nonLinear default): linear color space allocates
        // RGBA16F textures (8 bytes/px) rather than RGBA8 (4 bytes/px). For this
        // effect the perceptual difference is invisible — phosphor glow opacities
        // are all in a range where sRGB ≈ linear — but the doubled texture budget
        // caused GPU memory kills on A9/A10 devices running a full-screen canvas.
        return Canvas(opaque: false, rendersAsynchronously: false) { ctx, _ in
            // Pre-compute all char states in one sweep to avoid doing it twice.
            var infos: [MatrixCanvasCharInfo] = []
            infos.reserveCapacity(rows * columns)
            for rowIdx in 0..<rows {
                for item in charGrid[rowIdx] {
                    let info = computeMatrixChar(
                        item: item, row: rowIdx, col: item.id,
                        totalRows: rows, totalCols: columns,
                        fontSize: fontSize, charWidth: charWidth, lineH: lineH,
                        time: time, elapsedReveal: elapsedReveal, skipAnim: skipAnim
                    )
                    if info.visible { infos.append(info) }
                }
            }

            // ── Pass 1: blurred phosphor glow ──────────────────────────────
            // addFilter(.blur) applies a single GPU blur to EVERYTHING drawn in
            // this layer — one operation for all ~600 characters combined, vs the
            // old approach of one blur per character per layer (~2,400+ calls/frame).
            // WHY radius 4.0 (was 5.5): smaller kernel = less GPU bandwidth for the
            // offscreen blur pass. Still produces visible phosphor softening; the
            // tighter halo better matches real CRT phosphor spread.
            // WHY two ghost offsets (was three): dropping the farthest offset
            // (-fontSize * 1.1, opacity * 0.32) saves ~600 draw calls/frame with
            // no perceptible loss — the third ghost was barely visible under blur.
            ctx.drawLayer { gc in
                gc.addFilter(.blur(radius: 4.0))
                for info in infos where info.glowOpacity > 0.01 {
                    let p = CGPoint(x: info.x + info.lateralJitter, y: info.y)
                    gc.draw(Text(String(info.char)).foregroundStyle((info.color.opacity(info.glowOpacity * 0.52) as Color)),
                            at: p.applying(.init(translationX: 0, y: -fontSize * 0.55)), anchor: .topLeading)
                    gc.draw(Text(String(info.char)).foregroundStyle((info.color.opacity(info.glowOpacity) as Color)),
                            at: p, anchor: .topLeading)
                }
            }

            // ── Pass 2: sharp foreground characters ────────────────────────
            for info in infos where info.sharpOpacity > 0.01 {
                ctx.draw(
                    Text(String(info.char)).foregroundStyle((info.color.opacity(info.sharpOpacity) as Color)),
                    at: CGPoint(x: info.x + info.lateralJitter, y: info.y),
                    anchor: .topLeading
                )
            }
        }
        .font(.system(size: fontSize, weight: preferences.fontWeight.fontWeight, design: .monospaced))
        .allowsHitTesting(false)
        .frame(width: bodyWidth, height: CGFloat(rows) * lineH, alignment: .topLeading)
    }

    // Computes the visual state for one matrix character at a given (row, col) for
    // the current time. Pure function — no side effects, safe to call from Canvas draw.
    private func computeMatrixChar(
        item: MatrixCharItem, row: Int, col: Int,
        totalRows: Int, totalCols: Int,
        fontSize: CGFloat, charWidth: CGFloat, lineH: CGFloat,
        time: TimeInterval, elapsedReveal: Double, skipAnim: Bool
    ) -> MatrixCanvasCharInfo {
        let baseSeed    = matrixNoise(col, row)
        let columnSeed  = matrixColumnNoise(col)
        let streakSeed  = matrixNoise(col * 7 + row * 3, row * 11 + col)

        // ── Rain physics ─────────────────────────────────────────────────
        let streamDuration = 4.4 + columnSeed * 3.4 + Double((col + row) % 4) * 0.22
        let phase      = ((time + baseSeed * streamDuration).truncatingRemainder(dividingBy: streamDuration)) / streamDuration
        let easedPhase = phase * phase * (3.0 - 2.0 * phase)
        let spawnRows  = 5.0 + columnSeed * 8.0
        let trailRows  = (item.isHighlighted ? 9.0 : 13.0) + streakSeed * 7.0
        let headPos    = easedPhase * (Double(totalRows) + spawnRows + trailRows) - spawnRows
        let dist       = headPos - Double(row)

        let arrivalProgress = max(0.0, min(1.0, (dist + 2.2 + columnSeed * 2.8) / (2.2 + columnSeed * 2.8)))
        let trailProgress   = max(0.0, min(1.0, 1.0 - dist / trailRows))

        // ── Brightness ───────────────────────────────────────────────────
        // WHY highlighted chars bypass rain-head logic: date digits sit at a fixed
        // settled position, so letting the rain head spike their brightness to 2.2
        // would cause jarring flashes. Instead they always use the ambient flicker
        // formula — a gentle sine-based phosphor ebb and flow — while ambient digits
        // keep the full head/trail/decay cycle.
        let flickerRate = 0.9 + columnSeed * 1.8
        let flicker = (sin(time * flickerRate + baseSeed * 9.0 + Double(row) * (0.21 + columnSeed * 0.12)) + 1) * 0.5

        let brightness: Double
        let glowStrength: Double
        if item.isHighlighted {
            brightness   = 0.72 + flicker * 0.22
            glowStrength = 0.28 + flicker * 0.38
        } else if dist > -0.4 && dist <= 0.2 {
            brightness   = 1.85 + columnSeed * 0.40
            glowStrength = 0.8  + columnSeed * 0.2
        } else if dist > 0.2 && dist < trailRows {
            let t     = (dist - 0.2) / (trailRows - 0.2)
            let decay = pow(1.0 - t, 0.55)
            brightness   = (1.08 + columnSeed * 0.18) * decay
            glowStrength = decay * (0.5 + columnSeed * 0.3)
        } else {
            brightness   = 0.14 + flicker * (0.06 + streakSeed * 0.03)
            glowStrength = flicker * 0.1
        }

        let phosphorOpacity = item.isHighlighted
            ? 0.96
            : min(0.90, 0.18 + trailProgress * 0.70)

        // ── Reveal cascade (time-based spring approximation) ─────────────
        // WHY ease-out cubic instead of SwiftUI spring: Canvas has no per-node
        // animation state. We replicate the cascadeDelay + spring(0.30, 0.70)
        // with a simple ease-out cubic keyed on elapsed time since revealStartDate.
        let cascadeDelay = skipAnim ? 0.0
            : (Double(col) / Double(max(1, totalCols)) * 0.42)
            +  columnSeed * 0.22
            +  Double(row) * (0.001 + columnSeed * 0.003)

        let dropHeight = fontSize * CGFloat(spawnRows * 0.42)
        // WHY highlighted chars settle to 0 instead of -glideOffset: glideOffset is
        // derived from arrivalProgress which changes every frame as the rain head
        // cycles. Using it for highlighted chars would cause the date digits to drift
        // up/down continuously after landing. Lock them at their grid row instead.
        let settledOffset: CGFloat = item.isHighlighted
            ? 0
            : -CGFloat((1.0 - arrivalProgress) * (1.0 - arrivalProgress))
                * fontSize * CGFloat(1.7 + columnSeed * 3.2)

        let revealOpacity: Double
        let vertYOffset: CGFloat

        if elapsedReveal < 0 {
            // Not yet revealed — parked above the visible area.
            revealOpacity = 0
            vertYOffset   = -dropHeight
        } else if skipAnim {
            revealOpacity = 1
            vertYOffset   = settledOffset
        } else {
            let charElapsed = max(0.0, elapsedReveal - cascadeDelay)
            let t = min(1.0, charElapsed / 0.42)
            let sp = 1.0 - pow(1.0 - t, 3.0)  // ease-out cubic ≈ spring(0.30, 0.70)
            revealOpacity = sp
            // Lerp from "parked above" → settled position (0 for date, physics for ambient).
            vertYOffset = CGFloat(1.0 - sp) * (-dropHeight) + CGFloat(sp) * settledOffset
        }

        // ── Character mutation (head of rain glitches between glyphs) ────
        let headWindow   = dist > -0.18 && dist < trailRows * 0.28
        let displayChar  = matrixDisplayedCharacter(
            base: item.char, isHighlighted: item.isHighlighted,
            row: row, col: col, time: time, shouldMutate: headWindow
        )

        let lateralJitter: CGFloat = item.isHighlighted
            ? 0
            : CGFloat((matrixNoise(col * 13, row * 5) - 0.5) * 0.20)

        return MatrixCanvasCharInfo(
            char:         displayChar,
            color:        item.color,
            x:            CGFloat(col) * charWidth,
            y:            CGFloat(row) * lineH + vertYOffset,
            sharpOpacity: min(1.0, brightness) * phosphorOpacity * revealOpacity,
            glowOpacity:  glowStrength          * phosphorOpacity * revealOpacity,
            lateralJitter: lateralJitter,
            visible:      revealOpacity > 0.005
        )
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
        add(line.before, (ambientGreen.opacity(0.72) as Color), false)
        if line.isHighlighted {
            add(line.day,   accentGreen, true)
            add(line.month, headGreen,   true)
            add(line.year,  (accentGreen.opacity(0.94) as Color), true)
        }
        add(line.after, (ambientGreen.opacity(0.72) as Color), false)
        return items
    }


    private func composedBodyText(from layout: PiBodyLayout, palette: ThemePalette) -> Text {
        layout.lines.enumerated().reduce(Text("")) { partial, pair in
            let (index, line) = pair
            let newline = index == 0 ? Text("") : Text("\n")

            if line.isHighlighted {
                return partial
                + newline
                + Text(line.before).foregroundStyle((palette.mutedInk.opacity(0.62) as Color))
                + Text(line.day).foregroundStyle((palette.day.opacity(revealSequence ? 1 : 0.18) as Color))
                + Text(line.month).foregroundStyle((palette.month.opacity(revealSequence ? 1 : 0.18) as Color))
                + Text(line.year).foregroundStyle((palette.year.opacity(revealSequence ? 1 : 0.18) as Color))
                + Text(line.after).foregroundStyle((palette.mutedInk.opacity(0.62) as Color))
            }

            return partial
            + newline
            + Text(line.before).foregroundStyle((palette.mutedInk.opacity(0.62) as Color))
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
        let glyphWidth = max(1, cachedGlyphWidth(for: bodyFontSize))
        let viewportWidth = max(120, floor(usableWidth))
        // WHY ceil: we want bodyWidth ≥ viewportWidth so content always overflows
        // the right edge. clipped() in digitContextBody then cuts it cleanly.
        // floor-based columns + scaleEffect required accurate UIKit measurement;
        // ceil + clip is measurement-agnostic — overflow is guaranteed regardless
        // of how the font actually renders.
        // WHY + 2: guarantees the rendered text overflows the viewport even if the
        // actual SwiftUI advance width is marginally narrower than the UIKit measurement.
        let rawColumns = max(max(queryLength + 8, 16), Int(ceil(viewportWidth / glyphWidth)) + 2)
        let columns = alignedColumnCount(rawColumns, queryLength: queryLength)
        let bodyWidth = CGFloat(columns) * glyphWidth

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

    private func cachedBodyLayout(in size: CGSize, metrics: PiTextMetrics) -> PiBodyLayout {
        let query = viewModel.exactQuery
        let format = viewModel.activeFormat
        if let c = canvasCache.bodyLayout,
           c.size == size,
           c.query == query,
           c.format == format,
           c.fontStyle == preferences.fontStyle,
           c.weight == preferences.fontWeight,
           c.digitSize == preferences.digitSize {
            return c.layout
        }
        let layout = makeBodyLayout(in: size, metrics: metrics)
        canvasCache.bodyLayout = BodyLayoutCache(
            size: size,
            query: query,
            format: format,
            fontStyle: preferences.fontStyle,
            weight: preferences.fontWeight,
            digitSize: preferences.digitSize,
            layout: layout
        )
        return layout
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
    // Pass selectedDate so D/M/YYYY can determine the correct day digit count.
    private func highlightedParts(for query: String, format: DateFormatOption) -> (day: String, month: String, year: String) {
        format.queryParts(from: query, date: viewModel.selectedDate)
    }

    // MARK: - Helpers

    // WHY private static let: this string never changes. Recomputing it on every
    // body evaluation (which can happen many times per second during scrolling) wastes
    // CPU and allocates a new String instance each time. Hoisting it as a static
    // constant means exactly one allocation for the lifetime of the app.
    private static let piBase = "3.141592653589793238462643383279502884197169399375105820974944592"

    private func piLeadDigits(count: Int) -> String {
        // WHY clamp: repeating "31415926" beyond the known-correct digits is wrong.
        // Pi enthusiasts (the entire target demographic) will notice. Honest truncation
        // at the boundary is better than confident fiction.
        String(Self.piBase.prefix(min(count, Self.piBase.count)))
    }

    private func formattedPosition(_ storedPosition: Int) -> String {
        viewModel.displayedPosition(for: storedPosition).formatted(.number.grouping(.automatic))
    }

    private func measuredGlyphWidth(for fontSize: CGFloat) -> CGFloat {
        let uiFont = preferences.fontStyle.uiFont(size: fontSize, weight: preferences.fontWeight.fontWeight)
        // WHY 10-char sample without ceil: measuring a single character and rounding up
        // inflated the per-glyph width by up to 0.7 pt. Over 40+ columns that accumulates
        // into a visible gap on the right edge. Averaging across 10 glyphs gives a precise
        // fractional advance width that tracks what SwiftUI actually renders.
        let sample = "0000000000" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: uiFont]
        return sample.size(withAttributes: attributes).width / 10.0
    }

    private func cachedGlyphWidth(for fontSize: CGFloat) -> CGFloat {
        if let c = canvasCache.glyphWidth,
           c.fontStyle == preferences.fontStyle,
           c.weight == preferences.fontWeight,
           c.digitSize == preferences.digitSize,
           c.fontSize == fontSize {
            return c.width
        }
        let width = measuredGlyphWidth(for: fontSize)
        canvasCache.glyphWidth = GlyphWidthCache(
            fontStyle: preferences.fontStyle,
            weight: preferences.fontWeight,
            digitSize: preferences.digitSize,
            fontSize: fontSize,
            width: width
        )
        return width
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
        // WHY +1 instead of -1: bodyWidth must stay ≥ viewportWidth.
        // Subtracting shrinks below the viewport; adding keeps parity AND keeps overflow.
        return rawColumns + 1
    }

    // True when a lookup has completed with no match and no error.
    // WHY exclude isLoading: we don't want to flash the faded state during the
    // brief moment between navigation and lookup completion.
    // WHY exclude errorMessage: a network error shouldn't look like "not found".
    private var isNotFound: Bool {
        !viewModel.isLoading
            && viewModel.bestMatch == nil
            && viewModel.errorMessage == nil
            && viewModel.isSelectedDateInRange
    }

    private func focusGlow(palette: ThemePalette) -> some View {
        Group {
            if preferences.theme.isAnimated {
                // Matrix: phosphor-green CRT bloom — .screen adds light, which is
                // exactly the aesthetic for the retro terminal look.
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
            } else if preferences.effectiveColorScheme == .dark {
                // WHY dark vignette instead of .screen glow: the original white-based
                // focusGlow with .screen creates bright halos on dark backgrounds —
                // it ADDS visibility to edge text instead of fading it out. Overlaying
                // the theme's own background colour fades peripheral digits naturally
                // into the surrounding canvas, keeping the centre crisp.
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        (palette.background.opacity(0.55) as Color),
                        (palette.background.opacity(0.88) as Color)
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()
            } else {
                // Light themes: warm centre glow — .screen on a light background is
                // barely perceptible, just a subtle lift in the viewing area.
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

// Holds both layout caches as mutable class state.
// WHY class (not struct): @State holds a reference to this object. Mutating
// its properties does not change the @State reference, so SwiftUI never sees
// "state modified during view update" — the warning that fires when you assign
// new struct values to @State inside body.
private final class CanvasCache {
    var glyphWidth: GlyphWidthCache?
    var bodyLayout: BodyLayoutCache?
}

// Per-character data for Matrix rain rendering.
// id == column index, unique within each row's ForEach.
private struct MatrixCharItem: Identifiable {
    let id: Int
    let char: Character
    let color: Color
    let isHighlighted: Bool
}

// Fully resolved render state for one Canvas character, computed once per frame
// in computeMatrixChar and consumed by both the glow pass and sharp pass.
private struct MatrixCanvasCharInfo {
    let char: Character
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let sharpOpacity: Double   // opacity for the crisp foreground pass
    let glowOpacity: Double    // opacity for the blurred phosphor glow pass
    let lateralJitter: CGFloat
    let visible: Bool          // false when fully transparent (skip both passes)
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

private struct GlyphWidthCache {
    let fontStyle: AppFontStyle
    let weight: AppFontWeight
    let digitSize: DigitSize
    let fontSize: CGFloat
    let width: CGFloat
}

private struct BodyLayoutCache {
    let size: CGSize
    let query: String
    let format: DateFormatOption
    let fontStyle: AppFontStyle
    let weight: AppFontWeight
    let digitSize: DigitSize
    let layout: PiBodyLayout
}
