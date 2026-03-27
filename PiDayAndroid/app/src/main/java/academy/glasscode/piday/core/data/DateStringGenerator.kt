package academy.glasscode.piday.core.data

import academy.glasscode.piday.core.domain.DateFormatOption
import java.time.LocalDate

// WHY: Pure function — Date → list of (format, queryString) pairs.
// No Android dependencies; fully unit-testable on the plain JVM.
class DateStringGenerator {

    fun strings(date: LocalDate, formats: List<DateFormatOption>): List<Pair<DateFormatOption, String>> {
        val yyyy = "%04d".format(date.year)
        val yy   = "%02d".format(date.year % 100)
        val mm   = "%02d".format(date.monthValue)
        val dd   = "%02d".format(date.dayOfMonth)
        val d    = date.dayOfMonth.toString()   // no leading zero
        val m    = date.monthValue.toString()   // no leading zero

        return formats.map { format ->
            format to when (format) {
                DateFormatOption.YYYYMMDD             -> "$yyyy$mm$dd"
                DateFormatOption.DDMMYYYY             -> "$dd$mm$yyyy"
                DateFormatOption.MMDDYYYY             -> "$mm$dd$yyyy"
                DateFormatOption.YYMMDD               -> "$yy$mm$dd"
                DateFormatOption.DMY_NO_LEADING_ZEROS -> "$d$m${date.year}"
            }
        }
    }

    // Canonical ISO key used in the bundled index and lookup caches.
    fun isoDateString(date: LocalDate): String =
        "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
}
