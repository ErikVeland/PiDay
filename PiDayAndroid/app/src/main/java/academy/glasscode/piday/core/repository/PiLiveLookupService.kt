package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import java.time.LocalDate

/**
 * Legacy live lookup service.
 *
 * The release build is bundled-only (no fake/live fallback for dates). This class remains
 * in the codebase for potential future debug tooling, but is intentionally disabled.
 */
class PiLiveLookupService {
    private val generator = DateStringGenerator()

    suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val isoDate = generator.isoDateString(date)
        val queries = generator.strings(date, formats)

        return DateLookupSummary(
            isoDate      = isoDate,
            matches      = queries.map { (fmt, q) -> PiMatchResult(q, fmt, found = false, storedPosition = null, excerpt = null) },
            bestMatch    = null,
            source       = LookupSource.LIVE,
            errorMessage = "Live lookup is disabled in this release build."
        )
    }

    // Arbitrary digit-sequence search — used by FreeSearchViewModel.
    suspend fun searchDigits(digits: String): Pair<Int, String>? {
        return null
    }
}
