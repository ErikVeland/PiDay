package academy.glasscode.piday.core.domain

import java.time.LocalDate

data class CalendarDay(
    val date: LocalDate,
    val dayNumber: Int,
    val isInDisplayedMonth: Boolean
)

// DaySummary is the ViewModel-level type for one calendar cell.
// It combines date identity with digit-hit metadata so Composables are pure display logic.
data class DaySummary(
    val date: LocalDate,
    val dayNumber: Int,
    val isoDate: String,
    val isSelected: Boolean,
    val isInDisplayedMonth: Boolean,
    val isInBundledRange: Boolean,
    val bestStoredPosition: Int?,
    val foundFormats: Int
) {
    val isFound: Boolean get() = bestStoredPosition != null

    fun displayedBestPosition(convention: IndexingConvention): Int? =
        bestStoredPosition?.let { convention.displayPosition(it) }

    // WHY bestStoredPosition (not displayed): heat levels reflect the true position.
    // The display convention (0-based vs 1-based) is a UI labeling choice and should
    // NOT shift which heat bucket a date falls into.
    val heatLevel: PiHeatLevel get() = when (bestStoredPosition) {
        null                   -> PiHeatLevel.NONE
        in 0 until 1_000       -> PiHeatLevel.HOT
        in 0 until 100_000     -> PiHeatLevel.WARM
        in 0 until 10_000_000  -> PiHeatLevel.COOL
        else                   -> PiHeatLevel.FAINT
    }
}

enum class PiHeatLevel { NONE, FAINT, COOL, WARM, HOT }
