package academy.glasscode.piday.core.domain

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.util.UUID

// WHY: @Serializable replaces Swift's Codable. We store year/month/day as ints rather
// than serializing LocalDate directly, matching the iOS encoding so data stays
// portable if a future sync mechanism is added.
@Serializable
data class SavedDate(
    val id: String = UUID.randomUUID().toString(),
    var label: String,
    val year: Int,
    val month: Int,
    val day: Int
) {
    val date: LocalDate get() = LocalDate.of(year, month, day)
    val isoDate: String get() = "%04d-%02d-%02d".format(year, month, day)

    fun matches(other: LocalDate): Boolean =
        other.year == year && other.monthValue == month && other.dayOfMonth == day

    companion object {
        fun from(date: LocalDate, label: String): SavedDate = SavedDate(
            label = label,
            year  = date.year,
            month = date.monthValue,
            day   = date.dayOfMonth
        )
    }
}
