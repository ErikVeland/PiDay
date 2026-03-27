package academy.glasscode.piday.features.canvas

import academy.glasscode.piday.core.domain.BestPiMatch
import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.design.AppPalette
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.min

@Composable
fun PiCanvasView(
    excerpt: String?,
    bestMatch: BestPiMatch?,
    palette: AppPalette,
    modifier: Modifier = Modifier,
    onSwipeLeft: () -> Unit = {},
    onSwipeRight: () -> Unit = {},
    onSwipeUp: () -> Unit = {}
) {
    val textMeasurer = rememberTextMeasurer()

    val revealAlpha by animateFloatAsState(
        targetValue    = if (excerpt != null) 1f else 0f,
        animationSpec  = tween(400),
        label          = "reveal"
    )

    // Track drag start to compute direction after release
    var dragStartX by remember { mutableFloatStateOf(0f) }
    var dragStartY by remember { mutableFloatStateOf(0f) }
    var dragHandled by remember { mutableStateOf(false) }

    Canvas(
        modifier = modifier.pointerInput(Unit) {
            detectDragGestures(
                onDragStart = { offset ->
                    dragStartX  = offset.x
                    dragStartY  = offset.y
                    dragHandled = false
                },
                onDragEnd = {},
                onDrag = { change, _ ->
                    if (!dragHandled) {
                        val dx = change.position.x - dragStartX
                        val dy = change.position.y - dragStartY
                        if (abs(dx) > 60f || abs(dy) > 60f) {
                            dragHandled = true
                            when {
                                abs(dx) > abs(dy) && dx < 0 -> onSwipeLeft()
                                abs(dx) > abs(dy) && dx > 0 -> onSwipeRight()
                                dy < -60f                    -> onSwipeUp()
                            }
                        }
                    }
                }
            )
        }
    ) {
        if (excerpt == null || bestMatch == null) {
            drawPlaceholder(palette, textMeasurer)
            return@Canvas
        }
        drawDigitGrid(excerpt, bestMatch, palette, textMeasurer, revealAlpha)
    }
}

// Draws a dimmed placeholder stream of digits when no result is available yet.
private fun DrawScope.drawPlaceholder(palette: AppPalette, textMeasurer: TextMeasurer) {
    val placeholder = "3141592653589793238462643383279502884197169399375105820974944592307816406286"
    val style = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize   = 18.sp,
        color      = palette.onBackground.copy(alpha = 0.12f)
    )
    val charW = textMeasurer.measure("0", style).size.width.toFloat()
    val charH = textMeasurer.measure("0", style).size.height.toFloat()
    val cols  = floor(size.width / charW).toInt().coerceAtLeast(1)
    val rows  = floor(size.height / charH).toInt().coerceAtLeast(1)
    val total = cols * rows
    val stream = placeholder.repeat((total / placeholder.length) + 2)

    for (i in 0 until min(total, stream.length)) {
        drawText(
            textMeasurer = textMeasurer,
            text         = stream[i].toString(),
            style        = style,
            topLeft      = Offset((i % cols) * charW, (i / cols) * charH)
        )
    }
}

// Draws the full Pi digit grid with the matched date sequence color-coded.
private fun DrawScope.drawDigitGrid(
    excerpt: String,
    bestMatch: BestPiMatch,
    palette: AppPalette,
    textMeasurer: TextMeasurer,
    alpha: Float
) {
    val style = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize   = 18.sp,
        color      = palette.onBackground.copy(alpha = 0.35f * alpha)
    )
    val charW = textMeasurer.measure("0", style).size.width.toFloat()
    val charH = textMeasurer.measure("0", style).size.height.toFloat()
    val cols  = floor(size.width / charW).toInt().coerceAtLeast(1)
    val rows  = floor(size.height / charH).toInt().coerceAtLeast(1)

    // The excerpt is centered on the match; the match starts at ~half the excerpt length.
    val excerptRadius    = excerpt.length / 2
    val matchStartGlobal = excerptRadius
    val query            = bestMatch.query

    // Determine which global indices carry each date component color.
    val dayDigits = if (query.length <= 7) 1 else 2
    val parts  = bestMatch.format.queryParts(query, dayDigits)
    data class Segment(val start: Int, val end: Int, val color: Color)

    val segments: List<Segment> = when (bestMatch.format) {
        DateFormatOption.YYYYMMDD -> listOf(
            Segment(matchStartGlobal, matchStartGlobal + parts.year.length, palette.yearColor),
            Segment(matchStartGlobal + parts.year.length, matchStartGlobal + parts.year.length + parts.month.length, palette.monthColor),
            Segment(matchStartGlobal + parts.year.length + parts.month.length, matchStartGlobal + query.length, palette.dayColor),
        )
        DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS -> listOf(
            Segment(matchStartGlobal, matchStartGlobal + parts.day.length, palette.dayColor),
            Segment(matchStartGlobal + parts.day.length, matchStartGlobal + parts.day.length + parts.month.length, palette.monthColor),
            Segment(matchStartGlobal + parts.day.length + parts.month.length, matchStartGlobal + query.length, palette.yearColor),
        )
        DateFormatOption.MMDDYYYY -> listOf(
            Segment(matchStartGlobal, matchStartGlobal + parts.month.length, palette.monthColor),
            Segment(matchStartGlobal + parts.month.length, matchStartGlobal + parts.month.length + parts.day.length, palette.dayColor),
            Segment(matchStartGlobal + parts.month.length + parts.day.length, matchStartGlobal + query.length, palette.yearColor),
        )
        DateFormatOption.YYMMDD -> listOf(
            Segment(matchStartGlobal, matchStartGlobal + parts.year.length, palette.yearColor),
            Segment(matchStartGlobal + parts.year.length, matchStartGlobal + parts.year.length + parts.month.length, palette.monthColor),
            Segment(matchStartGlobal + parts.year.length + parts.month.length, matchStartGlobal + query.length, palette.dayColor),
        )
    }

    // Compute the visible window: center the match on screen.
    val visibleTotal  = cols * rows
    val centerRow     = rows / 2
    val matchCol      = matchStartGlobal % cols
    val matchGridIdx  = centerRow * cols + matchCol
    val excerptStart  = (matchStartGlobal - matchGridIdx).coerceAtLeast(0)

    for (gridIdx in 0 until visibleTotal) {
        val excerptIdx = excerptStart + gridIdx
        if (excerptIdx >= excerpt.length) break
        val globalIdx  = excerptIdx  // global == excerptIdx since excerpt IS the global window

        val charColor = segments.firstOrNull { globalIdx in it.start until it.end }
            ?.color?.copy(alpha = alpha)
            ?: palette.onBackground.copy(alpha = 0.35f * alpha)

        drawText(
            textMeasurer = textMeasurer,
            text         = excerpt[excerptIdx].toString(),
            style        = style.copy(color = charColor),
            topLeft      = Offset((gridIdx % cols) * charW, (gridIdx / cols) * charH)
        )
    }
}

// Convenience accessors — AppPalette already has these as named fields.
private val AppPalette.dayColor:   Color get() = this.dayColor
private val AppPalette.monthColor: Color get() = this.monthColor
private val AppPalette.yearColor:  Color get() = this.yearColor
