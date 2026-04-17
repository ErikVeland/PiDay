package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.data.PiIndexPayload
import academy.glasscode.piday.core.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.InputStream
import java.time.LocalDate

class PiStore(
    payload: PiIndexPayload? = null,
    private val featuredNumberForStats: CalendarFeaturedNumber = CalendarFeaturedNumber.PI
) {
    // WHY @Volatile: payload is written once (on a background thread during load)
    // then only read. @Volatile ensures all threads see the write immediately.
    @Volatile private var payload: PiIndexPayload? = payload
    @Volatile private var stats: PiStats? = payload?.let(::computeStats)
    private val generator = DateStringGenerator()

    // WHY lenient: the real index file may grow new fields; we don't want to crash.
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun loadFromStream(stream: InputStream) {
        // WHY Dispatchers.IO: reading 12MB from disk is blocking I/O.
        val loaded = withContext(Dispatchers.IO) {
            stream.use { json.decodeFromString<PiIndexPayload>(it.readBytes().decodeToString()) }
        }
        payload = loaded
        stats = computeStats(loaded)
    }

    val indexedYearRange: IntRange? get() {
        val meta = payload?.metadata ?: return null
        return meta.startYear..meta.endYear
    }

    val excerptRadius: Int get() = payload?.metadata?.excerptRadius ?: 20
    val piStats: PiStats? get() = stats

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

    private fun computeStats(payload: PiIndexPayload): PiStats {
        var earliest: PiStats.ExtremeMatch? = null
        var latest: PiStats.ExtremeMatch? = null
        var totalPositionNum = 0
        var matchCount = 0
        val formatCounts = mutableMapOf<DateFormatOption, Int>()
        val formatPositions = mutableMapOf<DateFormatOption, Int>()
        var maxPos = 0
        val featuredDays = mutableMapOf<Int, Int>()
        val bestDatePositions = mutableListOf<Int>()
        val bestDateMatches = mutableListOf<PiStats.ExtremeMatch>()
        val monthTotals = mutableMapOf<Int, Pair<Int, Int>>()
        val dayTotals = mutableMapOf<Int, Pair<Int, Int>>()
        var biggestUpset: PiStats.FormatUpset? = null
        var longestRepeatOddity: PiStats.QueryOddity? = null
        var uniqueDigitOddity: PiStats.QueryOddity? = null

        payload.dates.forEach { (isoDate, record) ->
            var bestForDate: PiStats.ExtremeMatch? = null
            var worstForDate: PiStats.ExtremeMatch? = null

            record.formatMap().forEach { (format, match) ->
                val pos = match.position

                if (earliest == null || pos < earliest!!.position) {
                    earliest = PiStats.ExtremeMatch(isoDate, pos, format, match.query)
                }
                if (latest == null || pos > latest!!.position) {
                    latest = PiStats.ExtremeMatch(isoDate, pos, format, match.query)
                }

                totalPositionNum += pos
                matchCount += 1
                formatCounts[format] = (formatCounts[format] ?: 0) + 1
                formatPositions[format] = (formatPositions[format] ?: 0) + pos
                maxPos = maxOf(maxPos, pos)

                if (isFeaturedDay(isoDate)) {
                    val year = isoDate.substring(0, 4).toIntOrNull() ?: 0
                    val current = featuredDays[year]
                    if (current == null || pos < current) {
                        featuredDays[year] = pos
                    }
                }

                val candidate = PiStats.ExtremeMatch(isoDate, pos, format, match.query)
                if (bestForDate == null || pos < bestForDate!!.position) bestForDate = candidate
                if (worstForDate == null || pos > worstForDate!!.position) worstForDate = candidate
            }

            if (bestForDate != null) {
                bestDatePositions += bestForDate!!.position
                bestDateMatches += bestForDate!!

                val parts = isoDate.split("-")
                if (parts.size == 3) {
                    val month = parts[1].toIntOrNull() ?: 0
                    val day = parts[2].toIntOrNull() ?: 0
                    if (month > 0) {
                        val (sum, count) = monthTotals[month] ?: (0 to 0)
                        monthTotals[month] = (sum + bestForDate!!.position) to (count + 1)
                    }
                    if (day > 0) {
                        val (sum, count) = dayTotals[day] ?: (0 to 0)
                        dayTotals[day] = (sum + bestForDate!!.position) to (count + 1)
                    }
                }

                val repeatRun = longestRepeatedRun(bestForDate!!.query)
                if (longestRepeatOddity == null || repeatRun > longestRepeatOddity!!.score) {
                    longestRepeatOddity = PiStats.QueryOddity(
                        bestForDate!!.date,
                        bestForDate!!.position,
                        bestForDate!!.format,
                        bestForDate!!.query,
                        repeatRun
                    )
                }

                val uniqueDigits = bestForDate!!.query.toSet().size
                if (uniqueDigitOddity == null || uniqueDigits > uniqueDigitOddity!!.score) {
                    uniqueDigitOddity = PiStats.QueryOddity(
                        bestForDate!!.date,
                        bestForDate!!.position,
                        bestForDate!!.format,
                        bestForDate!!.query,
                        uniqueDigits
                    )
                }
            }

            if (bestForDate != null && worstForDate != null) {
                val spread = worstForDate!!.position - bestForDate!!.position
                if (biggestUpset == null || spread > biggestUpset!!.spread) {
                    biggestUpset = PiStats.FormatUpset(
                        isoDate,
                        bestForDate!!.format,
                        bestForDate!!.position,
                        worstForDate!!.format,
                        worstForDate!!.position,
                        spread
                    )
                }
            }
        }

        val averagePosition = if (matchCount > 0) totalPositionNum / matchCount else 0
        val formatRates = buildMap {
            DateFormatOption.entries.forEach { format ->
                val count = formatCounts[format] ?: return@forEach
                if (count > 0) {
                    put(format, (formatPositions[format] ?: 0).toDouble() / count.toDouble())
                }
            }
        }
        val monthAverages = monthTotals.map { (month, pair) ->
            PiStats.MonthAggregate(month, pair.first / maxOf(pair.second, 1), pair.second)
        }
        val dayAverages = dayTotals.map { (day, pair) ->
            PiStats.DayOfMonthAggregate(day, pair.first / maxOf(pair.second, 1), pair.second)
        }

        return PiStats(
            earliestMatch = earliest,
            latestMatch = latest,
            averagePosition = averagePosition,
            formatSuccessRate = formatRates,
            totalDatesMatched = payload.dates.size,
            maxDigitReached = maxPos,
            piDayStats = featuredDays,
            bestDatePositions = bestDatePositions,
            topEarliestDates = bestDateMatches.sortedBy { it.position }.take(5),
            luckiestMonth = monthAverages.minByOrNull { it.averagePosition },
            hardestMonth = monthAverages.maxByOrNull { it.averagePosition },
            luckiestDayOfMonth = dayAverages.minByOrNull { it.averagePosition },
            hardestDayOfMonth = dayAverages.maxByOrNull { it.averagePosition },
            biggestFormatUpset = biggestUpset,
            longestRepeatRun = longestRepeatOddity,
            mostUniqueDigits = uniqueDigitOddity
        )
    }

    private fun isFeaturedDay(isoDate: String): Boolean {
        val suffix = String.format("-%02d-%02d", featuredNumberForStats.highlightMonth, featuredNumberForStats.highlightDay)
        return isoDate.endsWith(suffix)
    }

    private fun longestRepeatedRun(query: String): Int {
        var longest = 0
        var current = 0
        var previous: Char? = null

        query.forEach { ch ->
            if (ch == previous) {
                current += 1
            } else {
                current = 1
                previous = ch
            }
            longest = maxOf(longest, current)
        }

        return longest
    }
}
