package academy.glasscode.piday.core.domain

import java.time.LocalDate

/**
 * The active "digit universe" for the app (π / τ / e / φ / Planck).
 *
 * Requirement: all numbers are treated as equals.
 * The entire app (calendar, detail lookup, stats, battle, share) runs against the
 * selected featured number's bundled index.
 */
enum class CalendarFeaturedNumber(
    val rawValue: String,
    val logoSymbol: String,
    val heatMapSymbol: String,
    val title: String,
    val decimalPreview: String,
    val highlightMonth: Int,
    val highlightDay: Int,
) {
    PI(
        rawValue = "pi",
        logoSymbol = "π",
        heatMapSymbol = "π",
        title = "Pi",
        decimalPreview = "3.14159…",
        highlightMonth = 3,
        highlightDay = 14
    ),
    PI416(
        rawValue = "pi416",
        logoSymbol = "π",
        heatMapSymbol = "π",
        title = "Pi (4.16)",
        decimalPreview = "3.1416…",
        highlightMonth = 4,
        highlightDay = 16
    ),
    TAU(
        rawValue = "tau",
        logoSymbol = "τ",
        heatMapSymbol = "τ",
        title = "Tau",
        decimalPreview = "6.28318…",
        highlightMonth = 6,
        highlightDay = 28
    ),
    EULER(
        rawValue = "e",
        logoSymbol = "e",
        heatMapSymbol = "e",
        title = "Euler",
        decimalPreview = "2.71828…",
        highlightMonth = 2,
        highlightDay = 7
    ),
    GOLDEN_RATIO(
        rawValue = "phi",
        logoSymbol = "φ",
        heatMapSymbol = "φ",
        title = "Phi",
        decimalPreview = "1.61803…",
        highlightMonth = 11,
        highlightDay = 9
    ),
    PLANCK(
        rawValue = "planck",
        logoSymbol = "h",
        heatMapSymbol = "h",
        title = "Planck",
        decimalPreview = "6.62607×10⁻³⁴…",
        highlightMonth = 4,
        highlightDay = 14
    );

    val indexResourceName: String
        get() = when (this) {
            PI, PI416 -> "pi_2026_2035_index"
            TAU -> "tau_2026_2035_index"
            EULER -> "e_2026_2035_index"
            GOLDEN_RATIO -> "phi_2026_2035_index"
            PLANCK -> "planck_2026_2035_index"
        }

    val observedDayLabel: String
        get() = String.format("%02d/%02d", highlightMonth, highlightDay)

    fun highlights(date: LocalDate): Boolean =
        date.monthValue == highlightMonth && date.dayOfMonth == highlightDay

    companion object {
        fun fromRaw(raw: String?): CalendarFeaturedNumber? =
            entries.firstOrNull { it.rawValue == raw }
    }
}

