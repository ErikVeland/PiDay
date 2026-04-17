package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import java.io.InputStream
import java.time.LocalDate

// Legacy repository kept for historical reference.
// The production app now uses DefaultFeaturedNumberRepository (bundled-only, multi-number).
class DefaultPiRepository : PiRepository {
    private val store      = PiStore()
    private val generator  = DateStringGenerator()

    // Simple MutableMap cache. All VM access is on the main thread via viewModelScope,
    // so no concurrent writes. Error entries expire after 60 seconds.
    private val cache = mutableMapOf<String, Pair<DateLookupSummary, Long?>>()

    override val indexedYearRange: IntRange? get() = store.indexedYearRange
    override val excerptRadius: Int get() = store.excerptRadius
    override val piStats: PiStats? get() = store.piStats

    override suspend fun loadBundledIndex(stream: InputStream) {
        store.loadFromStream(stream)
        cache.clear()
    }

    override suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val key = cacheKey(date, formats)
        cache[key]?.let { (result, cachedAt) ->
            return result
        }

        val result = store.summary(date, formats)
        cache[key] = result to null
        return result
    }

    override fun bundledSummary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val key = cacheKey(date, formats)
        cache[key]?.let { (result, _) -> if (result.source == LookupSource.BUNDLED) return result }
        val result = store.summary(date, formats)
        cache[key] = result to null
        return result
    }

    override fun isInBundledRange(date: LocalDate) = store.isInIndexedRange(date)

    override fun clearCache() = cache.clear()

    private fun cacheKey(date: LocalDate, formats: List<DateFormatOption>): String {
        val iso = generator.isoDateString(date)
        val fmtKey = formats.map { it.serialName }.sorted().joinToString(",")
        return "$iso-$fmtKey"
    }
}
