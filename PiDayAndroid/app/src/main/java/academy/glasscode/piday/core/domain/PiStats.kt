package academy.glasscode.piday.core.domain

import java.text.NumberFormat
import java.time.LocalDate

data class PiStats(
    val earliestMatch: ExtremeMatch?,
    val latestMatch: ExtremeMatch?,
    val averagePosition: Int,
    val formatSuccessRate: Map<DateFormatOption, Double>,
    val totalDatesMatched: Int,
    val maxDigitReached: Int,
    val piDayStats: Map<Int, Int>,
    val bestDatePositions: List<Int>,
    val topEarliestDates: List<ExtremeMatch>,
    val luckiestMonth: MonthAggregate?,
    val hardestMonth: MonthAggregate?,
    val luckiestDayOfMonth: DayOfMonthAggregate?,
    val hardestDayOfMonth: DayOfMonthAggregate?,
    val biggestFormatUpset: FormatUpset?,
    val longestRepeatRun: QueryOddity?,
    val mostUniqueDigits: QueryOddity?
) {
    data class ExtremeMatch(
        val date: String,
        val position: Int,
        val format: DateFormatOption,
        val query: String
    )

    data class MonthAggregate(
        val month: Int,
        val averagePosition: Int,
        val dateCount: Int
    )

    data class DayOfMonthAggregate(
        val day: Int,
        val averagePosition: Int,
        val dateCount: Int
    )

    data class FormatUpset(
        val date: String,
        val bestFormat: DateFormatOption,
        val bestPosition: Int,
        val worstFormat: DateFormatOption,
        val worstPosition: Int,
        val spread: Int
    )

    data class QueryOddity(
        val date: String,
        val position: Int,
        val format: DateFormatOption,
        val query: String,
        val score: Int
    )
}

enum class SavedDatesSortOption(val title: String) {
    BEST_POSITION("Best Position"),
    LABEL("Label"),
    CALENDAR_DATE("Calendar Date")
}

data class RankedSavedDate(
    val savedDate: SavedDate,
    val rank: Int?,
    val bestStoredPosition: Int?,
    val bestFormat: DateFormatOption?,
    val percentileLabel: String?
)

enum class DateBattleWinner {
    LEFT,
    RIGHT,
    TIE
}

data class DateBattleContender(
    val date: LocalDate,
    val summary: DateLookupSummary,
    val displayedPosition: Int?,
    val percentileLabel: String
) {
    val bestMatch: BestPiMatch? get() = summary.bestMatch
    val isFound: Boolean get() = bestMatch != null
}

data class DateBattleResult(
    val left: DateBattleContender,
    val right: DateBattleContender,
    val winner: DateBattleWinner,
    val winningMargin: Int?,
    val verdict: String
) {
    val hasWinner: Boolean get() = winner != DateBattleWinner.TIE
}

enum class ShareCardStyle(val title: String) {
    CLASSIC("Classic"),
    NERD("Nerd"),
    BATTLE("Battle")
}

object PiDelightCopy {
    fun rarityLabel(storedPosition: Int?, allPositions: List<Int>): String {
        if (storedPosition == null || allPositions.isEmpty()) return "Unranked"
        val lowerCount = allPositions.count { it <= storedPosition }
        val percentile = maxOf(1, ((lowerCount.toDouble() / allPositions.size.toDouble()) * 100).toInt())
        return "Top $percentile%"
    }

    fun verdict(featured: CalendarFeaturedNumber, left: DateBattleContender, right: DateBattleContender, margin: Int?): String {
        val symbol = featured.heatMapSymbol
        return when (val lhs = left.displayedPosition) {
            null -> when (right.displayedPosition) {
                null -> "Neither date lands an exact hit here. $symbol remains mysterious."
                else -> "Right date wins by existing at all. Brutal, but fair."
            }
            else -> when (val rhs = right.displayedPosition) {
                null -> "Left date wins by existing at all. Brutal, but fair."
                else -> {
                    when {
                        lhs == rhs -> "It's a dead heat. $symbol refuses to pick a favorite."
                        margin != null && margin < 1_000 && lhs < rhs ->
                            "Left date squeaks past the right date by only ${margin.formattedNumber()} digits."
                        margin != null && margin < 1_000 && lhs > rhs ->
                            "Right date squeaks past the left date by only ${margin.formattedNumber()} digits."
                        margin != null && margin < 1_000_000 && lhs < rhs ->
                            "Left date wins comfortably, beating the right date by ${margin.formattedNumber()} digits."
                        margin != null && margin < 1_000_000 && lhs > rhs ->
                            "Right date wins comfortably, beating the left date by ${margin.formattedNumber()} digits."
                        lhs < rhs -> "Left date absolutely steamrolls the right date. $symbol can be ruthless."
                        else -> "Right date absolutely steamrolls the left date. $symbol can be ruthless."
                    }
                }
            }
        }
    }

    fun detailFact(featured: CalendarFeaturedNumber, date: LocalDate, bestMatch: BestPiMatch?): String? {
        if (featured.highlights(date)) {
            return "${featured.observedDayLabel} is ${featured.title} Day. Naturally it gets special treatment around here."
        }
        if (date.monthValue == 2 && date.dayOfMonth == 29) {
            return "Leap day only shows up when the calendar feels extra mischievous."
        }
        if (bestMatch != null && longestRepeatedRun(bestMatch.query) >= 3) {
            return "That query has a satisfyingly repetitive streak. Patterns are always fun."
        }
        if (bestMatch != null && bestMatch.storedPosition < 1_000) {
            return "That's an absurdly early hit. You basically found a unicorn."
        }
        if (bestMatch != null && bestMatch.storedPosition > 1_000_000_000) {
            return "This one is buried deep. Commitment was required."
        }
        return null
    }

    fun freeSearchReaction(query: String): String? = when (query) {
        "42" -> "Deep thought approves."
        "404" -> "Sequence found. Error joke denied."
        "1337" -> "Elite digits detected."
        "8675309" -> "Jenny mode unlocked."
        else -> null
    }

    fun battleShareText(battle: DateBattleResult): String {
        val leftLabel = battle.left.date.toString()
        val rightLabel = battle.right.date.toString()
        val leftLine = battle.left.displayedPosition?.let {
            "$leftLabel hits at digit ${it.formattedNumber()} in ${battle.left.bestMatch?.format?.displayName ?: "unknown"}"
        } ?: "$leftLabel has no exact hit in the active search formats"
        val rightLine = battle.right.displayedPosition?.let {
            "$rightLabel hits at digit ${it.formattedNumber()} in ${battle.right.bestMatch?.format?.displayName ?: "unknown"}"
        } ?: "$rightLabel has no exact hit in the active search formats"
        return buildString {
            appendLine("PiDay Date Battle")
            appendLine(battle.verdict)
            appendLine(leftLine)
            appendLine(rightLine)
            if (battle.hasWinner && battle.winningMargin != null) {
                append("Winning margin: ${battle.winningMargin.formattedNumber()} digits")
            }
        }.trim()
    }

    private fun longestRepeatedRun(query: String): Int {
        var longest = 0
        var current = 0
        var previous: Char? = null

        for (ch in query) {
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

fun Int.formattedNumber(): String = NumberFormat.getIntegerInstance().format(this)
