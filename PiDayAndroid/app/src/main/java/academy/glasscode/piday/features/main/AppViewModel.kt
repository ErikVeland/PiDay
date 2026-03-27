package academy.glasscode.piday.features.main

import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.core.repository.DefaultPiRepository
import academy.glasscode.piday.core.repository.PiRepository
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate
import java.time.YearMonth

// WHY AndroidViewModel: we need Application context to open the raw resource stream.
// This is the Kotlin/Android equivalent of iOS's @MainActor @Observable AppViewModel.
class AppViewModel @JvmOverloads constructor(
    app: Application,
    private val repository: PiRepository = DefaultPiRepository()
) : AndroidViewModel(app) {

    // --- Observable state ---
    private val _selectedDate    = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _displayedMonth  = MutableStateFlow(YearMonth.now())
    val displayedMonth: StateFlow<YearMonth> = _displayedMonth.asStateFlow()

    private val _lookupSummary   = MutableStateFlow<DateLookupSummary?>(null)
    val lookupSummary: StateFlow<DateLookupSummary?> = _lookupSummary.asStateFlow()

    private val _isLoading       = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _daySummaries    = MutableStateFlow<List<DaySummary>>(emptyList())
    val daySummaries: StateFlow<List<DaySummary>> = _daySummaries.asStateFlow()

    // These are mutated only on the main thread (viewModelScope), so no StateFlow needed.
    var searchPreference: SearchFormatPreference = SearchFormatPreference.INTERNATIONAL
        private set
    var indexingConvention: IndexingConvention = IndexingConvention.ONE_BASED
        private set

    val today: LocalDate = LocalDate.now()

    // WHY a cancellable job: cancels any in-flight lookup so stale results can't
    // overwrite the current selection — mirrors iOS's cancellable lookupTask.
    private var lookupJob: Job? = null

    // WHY LinkedHashMap with accessOrder=true: gives LRU eviction for free.
    // Month summaries are expensive (scan all ~35 bundled dates); caching 6 months
    // covers the typical "swipe back and forth" usage pattern.
    private val monthSummaryCache = LinkedHashMap<YearMonth, List<DaySummary>>(8, 0.75f, true)
    private val maxCacheSize = 6

    init {
        viewModelScope.launch { load() }
    }

    private suspend fun load() {
        _isLoading.value = true
        try {
            val ctx = getApplication<Application>()
            val resId = ctx.resources.getIdentifier(
                "pi_2026_2035_index", "raw", ctx.packageName
            )
            val stream = ctx.resources.openRawResource(resId)
            repository.loadBundledIndex(stream)
        } catch (e: Exception) {
            // Index load failure is non-fatal — live lookups still work for individual dates.
        }
        _isLoading.value = false
        refreshLookup()
        refreshDaySummaries()
    }

    fun selectDate(date: LocalDate) {
        _selectedDate.value = date
        _displayedMonth.value = YearMonth.of(date.year, date.month)
        scheduleRefresh()
    }

    fun nextDay()     = selectDate(_selectedDate.value.plusDays(1))
    fun previousDay() = selectDate(_selectedDate.value.minusDays(1))

    fun setDisplayedMonth(month: YearMonth) {
        _displayedMonth.value = month
        refreshDaySummaries()
    }

    fun setSearchPreference(pref: SearchFormatPreference) {
        searchPreference = pref
        repository.clearCache()
        monthSummaryCache.clear()
        scheduleRefresh()
        refreshDaySummaries()
    }

    fun setIndexingConvention(convention: IndexingConvention) {
        indexingConvention = convention
    }

    private fun scheduleRefresh() {
        lookupJob?.cancel()
        lookupJob = viewModelScope.launch {
            delay(50) // debounce rapid day swipes
            refreshLookup()
        }
    }

    private suspend fun refreshLookup() {
        _lookupSummary.value = repository.summary(_selectedDate.value, searchPreference.formats)
    }

    fun refreshDaySummaries() {
        viewModelScope.launch {
            val month    = _displayedMonth.value
            val selected = _selectedDate.value

            // Cache hit: just flip the isSelected flag, avoid a full rebuild.
            monthSummaryCache[month]?.let { cached ->
                _daySummaries.value = cached.map { it.copy(isSelected = it.date == selected) }
                return@launch
            }

            val summaries = withContext(Dispatchers.Default) {
                buildMonthSummaries(month, selected)
            }
            storeSummaryCache(summaries, month)
            _daySummaries.value = summaries
        }
    }

    private fun buildMonthSummaries(month: YearMonth, selected: LocalDate): List<DaySummary> {
        val formats  = searchPreference.formats
        val firstDay = month.atDay(1)
        val lastDay  = month.atEndOfMonth()

        // Build a full calendar grid starting on Sunday.
        // dayOfWeek: MON=1..SUN=7; we want SUN=0..SAT=6.
        val startOffset = (firstDay.dayOfWeek.value % 7)
        val days = mutableListOf<LocalDate>()
        repeat(startOffset) { i -> days.add(firstDay.minusDays((startOffset - i).toLong())) }
        var d = firstDay
        while (!d.isAfter(lastDay)) { days.add(d); d = d.plusDays(1) }
        while (days.size % 7 != 0) days.add(days.last().plusDays(1))

        return days.map { date ->
            val bundled = repository.bundledSummary(date, formats)
            DaySummary(
                date               = date,
                dayNumber          = date.dayOfMonth,
                isoDate            = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth),
                isSelected         = date == selected,
                isInDisplayedMonth = date.month == month.month,
                isInBundledRange   = repository.isInBundledRange(date),
                bestStoredPosition = bundled.bestMatch?.storedPosition,
                foundFormats       = bundled.foundCount
            )
        }
    }

    private fun storeSummaryCache(summaries: List<DaySummary>, month: YearMonth) {
        if (monthSummaryCache.size >= maxCacheSize) {
            monthSummaryCache.remove(monthSummaryCache.keys.first())
        }
        monthSummaryCache[month] = summaries
    }
}
