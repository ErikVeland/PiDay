package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import java.io.InputStream
import java.time.LocalDate

// WHY: DefaultPiRepository owns the routing decision — bundled index vs live API.
// AppViewModel asks "give me a summary"; it never decides which source to use.
class DefaultPiRepository : PiRepository {
    private val store      = PiStore()
    private val liveLookup = PiLiveLookupService()
    private val generator  = DateStringGenerator()

    // Simple MutableMap cache. All VM access is on the main thread via viewModelScope,
    // so no concurrent writes. Error entries expire after 60 seconds.
    private val cache = mutableMapOf<String, Pair<DateLookupSummary, Long?>>()
    private val errorCacheTtlMs = 60_000L

    override val indexedYearRange: IntRange? get() = store.indexedYearRange
    override val excerptRadius: Int get() = store.excerptRadius

    override suspend fun loadBundledIndex(stream: InputStream) {
        store.loadFromStream(stream)
        cache.clear()
    }

    override suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val key = cacheKey(date, formats)
        cache[key]?.let { (result, cachedAt) ->
            if (result.errorMessage != null && cachedAt != null) {
                if (System.currentTimeMillis() - cachedAt < errorCacheTtlMs) return result
                else cache.remove(key)
            } else {
                return result
            }
        }

        val result = if (store.isInIndexedRange(date)) {
            store.summary(date, formats)
        } else {
            runCatching { liveLookup.summary(date, formats) }.getOrElse { error ->
                val isoDate = generator.isoDateString(date)
                val queries = generator.strings(date, formats)
                DateLookupSummary(
                    isoDate      = isoDate,
                    matches      = queries.map { (fmt, q) -> PiMatchResult(q, fmt, false, null, null) },
                    bestMatch    = null,
                    source       = LookupSource.LIVE,
                    errorMessage = error.message
                )
            }
        }

        cache[key] = result to (if (result.errorMessage != null) System.currentTimeMillis() else null)
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
