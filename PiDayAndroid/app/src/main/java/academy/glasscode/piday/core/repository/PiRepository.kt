package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.core.domain.DateLookupSummary
import java.io.InputStream
import java.time.LocalDate

// WHY an interface: AppViewModel depends on this, not the concrete impl.
// Tests inject FakePiRepository; production uses DefaultPiRepository.
interface PiRepository {
    suspend fun loadBundledIndex(stream: InputStream)
    suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary
    fun bundledSummary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary
    fun isInBundledRange(date: LocalDate): Boolean
    fun clearCache()
    val indexedYearRange: IntRange?
    val excerptRadius: Int
}
