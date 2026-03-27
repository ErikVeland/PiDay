package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.data.PiIndexPayload
import academy.glasscode.piday.core.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.InputStream
import java.time.LocalDate

class PiStore(payload: PiIndexPayload? = null) {
    // WHY @Volatile: payload is written once (on a background thread during load)
    // then only read. @Volatile ensures all threads see the write immediately.
    @Volatile private var payload: PiIndexPayload? = payload
    private val generator = DateStringGenerator()

    // WHY lenient: the real index file may grow new fields; we don't want to crash.
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun loadFromStream(stream: InputStream) {
        // WHY Dispatchers.IO: reading 12MB from disk is blocking I/O.
        val loaded = withContext(Dispatchers.IO) {
            stream.use { json.decodeFromString<PiIndexPayload>(it.readBytes().decodeToString()) }
        }
        payload = loaded
    }

    val indexedYearRange: IntRange? get() {
        val meta = payload?.metadata ?: return null
        return meta.startYear..meta.endYear
    }

    val excerptRadius: Int get() = payload?.metadata?.excerptRadius ?: 20

    fun isInIndexedRange(date: LocalDate): Boolean {
        val range = indexedYearRange ?: return false
        return date.year in range
    }

    fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val isoDate = generator.isoDateString(date)
        val queries = generator.strings(date, formats)
        val formatMap = payload?.dates?.get(isoDate)?.formatMap() ?: emptyMap()

        val matches = queries.map { (format, query) ->
            val hit = formatMap[format]
            if (hit != null && hit.query == query) {
                PiMatchResult(query, format, found = true, storedPosition = hit.position, excerpt = hit.excerpt)
            } else {
                PiMatchResult(query, format, found = false, storedPosition = null, excerpt = null)
            }
        }.sortedWith(PiMatchResult.byPosition)

        val bestMatch = matches
            .mapNotNull { r ->
                if (r.storedPosition != null && r.excerpt != null)
                    BestPiMatch(r.format, r.query, r.storedPosition, r.excerpt)
                else null
            }
            .minWithOrNull(BestPiMatch.preferringPadded)

        return DateLookupSummary(
            isoDate      = isoDate,
            matches      = matches,
            bestMatch    = bestMatch,
            source       = LookupSource.BUNDLED,
            errorMessage = null
        )
    }
}
