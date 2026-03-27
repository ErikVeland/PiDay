package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.LocalDate

class PiLiveLookupService(
    private val excerptRadius: Int = 496
) {
    @Serializable private data class LookupResponse(
        val resultStringIdx: Int,
        val numResults: Int
    )

    @Serializable private data class DigitsResponse(val content: String)

    private val generator = DateStringGenerator()

    // WHY a single shared client: Ktor clients hold a thread pool.
    // Creating one per request would leak resources. Concurrent use is safe.
    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
        engine {
            connectTimeout = 12_000
            socketTimeout  = 30_000
        }
    }

    suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val isoDate = generator.isoDateString(date)
        val queries = generator.strings(date, formats)

        // WHY coroutineScope + async/awaitAll: fires all format lookups in parallel,
        // equivalent to iOS's withThrowingTaskGroup. Cuts latency from O(n*RTT) to O(RTT).
        val matches: List<PiMatchResult> = coroutineScope {
            queries.map { (format, query) ->
                async {
                    runCatching { lookup(query, format) }
                        .getOrElse { null }
                        ?: PiMatchResult(query, format, found = false, storedPosition = null, excerpt = null)
                }
            }.awaitAll()
        }.sortedWith(PiMatchResult.byPosition)

        val bestMatch = matches.mapNotNull { r ->
            if (r.storedPosition != null && r.excerpt != null)
                BestPiMatch(r.format, r.query, r.storedPosition, r.excerpt)
            else null
        }.minWithOrNull(BestPiMatch.preferringPadded)

        return DateLookupSummary(
            isoDate      = isoDate,
            matches      = matches,
            bestMatch    = bestMatch,
            source       = LookupSource.LIVE,
            errorMessage = null
        )
    }

    // Arbitrary digit-sequence search — used by FreeSearchViewModel.
    suspend fun searchDigits(digits: String): Pair<Int, String>? {
        val result = lookup(digits, DateFormatOption.DDMMYYYY) ?: return null
        val position = result.storedPosition ?: return null
        val excerpt  = result.excerpt ?: return null
        return position to excerpt
    }

    private suspend fun lookup(query: String, format: DateFormatOption): PiMatchResult? {
        val response: LookupResponse = client.get(
            "https://v2.api.pisearch.joshkeegan.co.uk/api/v1/Lookup"
        ) {
            parameter("namedDigits", "pi")
            parameter("find", query)
            parameter("resultId", "0")
        }.body()

        if (response.numResults == 0) return null

        val storedPosition = response.resultStringIdx + 1
        val excerpt = fetchExcerpt(storedPosition, query)
        return PiMatchResult(query, format, found = true, storedPosition = storedPosition, excerpt = excerpt)
    }

    private suspend fun fetchExcerpt(position: Int, query: String): String {
        val start = maxOf(1, position - excerptRadius)
        val response: DigitsResponse = client.get("https://api.pi.delivery/v1/pi") {
            parameter("start", start)
            parameter("numberOfDigits", query.length + excerptRadius * 2)
        }.body()

        val offset = minOf(excerptRadius, position - 1)
        val content = response.content
        require(offset < content.length && content.substring(offset).startsWith(query)) {
            "Live pi lookup: excerpt did not contain the expected query at offset $offset"
        }
        return content
    }
}
