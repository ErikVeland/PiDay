package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.domain.CalendarFeaturedNumber
import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.core.domain.DateLookupSummary
import academy.glasscode.piday.core.domain.PiStats
import android.content.Context
import java.time.LocalDate

/**
 * Bundled-only repository for all featured numbers.
 *
 * Requirement: no fake data.
 * We only return results from real, bundled indexes for each number mode.
 */
interface FeaturedNumberRepository {
    suspend fun loadBundledIndexes(context: Context)
    fun indexedYearRange(featured: CalendarFeaturedNumber): IntRange?
    fun excerptRadius(featured: CalendarFeaturedNumber): Int
    fun stats(featured: CalendarFeaturedNumber): PiStats?
    fun summary(featured: CalendarFeaturedNumber, date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary
    fun clearCache()
}

