package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import android.content.Context
import java.time.LocalDate

class DefaultFeaturedNumberRepository : FeaturedNumberRepository {
    private val generator = DateStringGenerator()
    private val stores = mutableMapOf<CalendarFeaturedNumber, PiStore>()

    // Cache by (featured + isoDate + formats)
    private val cache = mutableMapOf<String, DateLookupSummary>()

    override suspend fun loadBundledIndexes(context: Context) {
        // PiStore.loadFromStream does IO work off the main thread.
        CalendarFeaturedNumber.entries.forEach { featured ->
            val resId = context.resources.getIdentifier(featured.indexResourceName, "raw", context.packageName)
            require(resId != 0) { "Missing bundled index resource: ${featured.indexResourceName}.json" }
            val stream = context.resources.openRawResource(resId)
            store(featured).loadFromStream(stream)
        }
        cache.clear()
    }

    override fun indexedYearRange(featured: CalendarFeaturedNumber): IntRange? =
        store(featured).indexedYearRange

    override fun excerptRadius(featured: CalendarFeaturedNumber): Int =
        store(featured).excerptRadius

    override fun stats(featured: CalendarFeaturedNumber): PiStats? =
        store(featured).piStats

    override fun summary(
        featured: CalendarFeaturedNumber,
        date: LocalDate,
        formats: List<DateFormatOption>
    ): DateLookupSummary {
        val range = indexedYearRange(featured)
        val iso = generator.isoDateString(date)
        if (range == null) {
            return DateLookupSummary(
                isoDate = iso,
                matches = generator.strings(date, formats).map { (fmt, q) -> PiMatchResult(q, fmt, false, null, null) },
                bestMatch = null,
                source = LookupSource.BUNDLED,
                errorMessage = "Bundled index unavailable."
            )
        }
        if (date.year !in range) {
            return DateLookupSummary(
                isoDate = iso,
                matches = generator.strings(date, formats).map { (fmt, q) -> PiMatchResult(q, fmt, false, null, null) },
                bestMatch = null,
                source = LookupSource.BUNDLED,
                errorMessage = "Outside bundled index range."
            )
        }

        val key = cacheKey(featured, date, formats)
        cache[key]?.let { return it }
        val result = store(featured).summary(date, formats)
        cache[key] = result
        return result
    }

    override fun clearCache() {
        cache.clear()
    }

    private fun store(featured: CalendarFeaturedNumber): PiStore =
        stores.getOrPut(featured) { PiStore(featuredNumberForStats = featured) }

    private fun cacheKey(featured: CalendarFeaturedNumber, date: LocalDate, formats: List<DateFormatOption>): String {
        val iso = generator.isoDateString(date)
        val fmtKey = formats.map { it.serialName }.sorted().joinToString(",")
        return "${featured.rawValue}-$iso-$fmtKey"
    }
}
