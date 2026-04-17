package academy.glasscode.piday.features.main

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.core.repository.DefaultFeaturedNumberRepository
import academy.glasscode.piday.core.repository.FeaturedNumberRepository
import academy.glasscode.piday.services.PreferencesStore
import academy.glasscode.piday.services.SavedDatesStore
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

class AppViewModel @JvmOverloads constructor(
    app: Application,
    private val repository: FeaturedNumberRepository = DefaultFeaturedNumberRepository()
) : AndroidViewModel(app) {

    private val prefsStore = PreferencesStore(app)
    private val savedDatesStore = SavedDatesStore(app)
    private val generator = DateStringGenerator()

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _displayedMonth = MutableStateFlow(YearMonth.now())
    val displayedMonth: StateFlow<YearMonth> = _displayedMonth.asStateFlow()

    private val _lookupSummary = MutableStateFlow<DateLookupSummary?>(null)
    val lookupSummary: StateFlow<DateLookupSummary?> = _lookupSummary.asStateFlow()

    private val _featuredNumber = MutableStateFlow(CalendarFeaturedNumber.PI)
    val featuredNumber: StateFlow<CalendarFeaturedNumber> = _featuredNumber.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _daySummaries = MutableStateFlow<List<DaySummary>>(emptyList())
    val daySummaries: StateFlow<List<DaySummary>> = _daySummaries.asStateFlow()

    private val _savedDates = MutableStateFlow<List<SavedDate>>(emptyList())
    val savedDates: StateFlow<List<SavedDate>> = _savedDates.asStateFlow()

    var searchPreference: SearchFormatPreference = SearchFormatPreference.INTERNATIONAL
        private set
    var indexingConvention: IndexingConvention = IndexingConvention.ONE_BASED
        private set

    val today: LocalDate = LocalDate.now()

    private var lookupJob: Job? = null
    private val monthSummaryCache = LinkedHashMap<YearMonth, List<DaySummary>>(8, 0.75f, true)
    private val maxCacheSize = 6

    init {
        viewModelScope.launch {
            savedDatesStore.savedDates.collect { _savedDates.value = it }
        }
        viewModelScope.launch { load() }
    }

    val stats: PiStats? get() = repository.stats(_featuredNumber.value)
    val isCurrentDateSaved: Boolean get() = _savedDates.value.any { it.matches(_selectedDate.value) }
    val selectedDateFunFact: String? get() = PiDelightCopy.detailFact(_featuredNumber.value, _selectedDate.value, _lookupSummary.value?.bestMatch)

    val exactQuery: String
        get() = _lookupSummary.value?.bestMatch?.query
            ?: generator.strings(_selectedDate.value, listOf(searchPreference.heroFormat)).firstOrNull()?.second.orEmpty()

    suspend fun load() {
        _isLoading.value = true
        try {
            searchPreference = prefsStore.formatPrefFlow.first()
            indexingConvention = prefsStore.indexingFlow.first()
            _featuredNumber.value = prefsStore.featuredNumberFlow.first()
        } catch (_: Exception) {
        }

        try {
            val ctx = getApplication<Application>()
            repository.loadBundledIndexes(ctx)
        } catch (_: Exception) {
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

    fun nextDay() = selectDate(_selectedDate.value.plusDays(1))
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

    fun setFeaturedNumber(featured: CalendarFeaturedNumber) {
        if (_featuredNumber.value == featured) return
        _featuredNumber.value = featured
        viewModelScope.launch { prefsStore.setFeaturedNumber(featured) }
        repository.clearCache()
        monthSummaryCache.clear()
        scheduleRefresh()
        refreshDaySummaries()
    }

    fun setIndexingConvention(convention: IndexingConvention) {
        indexingConvention = convention
    }

    fun displayedPosition(storedPosition: Int): Int = indexingConvention.displayPosition(storedPosition)

    fun toggleSaveCurrentDate() {
        viewModelScope.launch {
            if (isCurrentDateSaved) {
                val updated = _savedDates.value.filterNot { it.matches(_selectedDate.value) }
                savedDatesStore.save(updated)
            } else {
                val label = _selectedDate.value.format(DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault()))
                val updated = _savedDates.value + SavedDate.from(_selectedDate.value, label)
                savedDatesStore.save(updated.distinctBy { it.isoDate })
            }
        }
    }

    fun updateSavedDateLabel(savedDateId: String, label: String) {
        viewModelScope.launch {
            val trimmed = label.trim()
            if (trimmed.isEmpty()) return@launch
            val updated = _savedDates.value.map { saved ->
                if (saved.id == savedDateId) saved.copy(label = trimmed) else saved
            }
            savedDatesStore.save(updated)
        }
    }

    fun deleteSavedDate(savedDateId: String) {
        viewModelScope.launch {
            savedDatesStore.save(_savedDates.value.filterNot { it.id == savedDateId })
        }
    }

    fun rankedSavedDates(sortedBy: SavedDatesSortOption): List<RankedSavedDate> {
        val allPositions = repository.stats(_featuredNumber.value)?.bestDatePositions.orEmpty()
        val ranked = _savedDates.value.map { saved ->
            val summary = repository.summary(_featuredNumber.value, saved.date, SearchFormatPreference.ALL.formats)
            val best = summary.bestMatch
            RankedSavedDate(
                savedDate = saved,
                rank = null,
                bestStoredPosition = best?.storedPosition,
                bestFormat = best?.format,
                percentileLabel = if (best == null) null else PiDelightCopy.rarityLabel(best.storedPosition, allPositions)
            )
        }

        val sorted = when (sortedBy) {
            SavedDatesSortOption.BEST_POSITION -> ranked.sortedWith(compareBy<RankedSavedDate> { it.bestStoredPosition == null }
                .thenBy { it.bestStoredPosition ?: Int.MAX_VALUE }
                .thenBy { it.savedDate.isoDate })
            SavedDatesSortOption.LABEL -> ranked.sortedBy { it.savedDate.label.lowercase(Locale.getDefault()) }
            SavedDatesSortOption.CALENDAR_DATE -> ranked.sortedBy { it.savedDate.isoDate }
        }

        return sorted.mapIndexed { index, item ->
            item.copy(rank = if (item.bestStoredPosition == null) null else index + 1)
        }
    }

    suspend fun compareCurrentDate(to: LocalDate): DateBattleResult {
        return compareDates(_selectedDate.value, to)
    }

    suspend fun compareDates(leftDate: LocalDate, rightDate: LocalDate): DateBattleResult {
        return coroutineScope {
            val featured = _featuredNumber.value
            val leftSummary = async { repository.summary(featured, leftDate, searchPreference.formats) }
            val rightSummary = async { repository.summary(featured, rightDate, searchPreference.formats) }
            compareDates(leftDate, leftSummary.await(), rightDate, rightSummary.await())
        }
    }

    fun compareDates(
        leftDate: LocalDate,
        leftSummary: DateLookupSummary,
        rightDate: LocalDate,
        rightSummary: DateLookupSummary
    ): DateBattleResult {
        val featured = _featuredNumber.value
        val positions = repository.stats(featured)?.bestDatePositions.orEmpty()
        val leftDisplayed = leftSummary.bestMatch?.storedPosition?.let(::displayedPosition)
        val rightDisplayed = rightSummary.bestMatch?.storedPosition?.let(::displayedPosition)

        val left = DateBattleContender(
            date = leftDate,
            summary = leftSummary,
            displayedPosition = leftDisplayed,
            percentileLabel = PiDelightCopy.rarityLabel(leftSummary.bestMatch?.storedPosition, positions)
        )
        val right = DateBattleContender(
            date = rightDate,
            summary = rightSummary,
            displayedPosition = rightDisplayed,
            percentileLabel = PiDelightCopy.rarityLabel(rightSummary.bestMatch?.storedPosition, positions)
        )

        val winner: DateBattleWinner
        val margin: Int?
        when {
            leftDisplayed != null && rightDisplayed != null && leftDisplayed == rightDisplayed -> {
                winner = DateBattleWinner.TIE
                margin = 0
            }
            leftDisplayed != null && rightDisplayed != null && leftDisplayed < rightDisplayed -> {
                winner = DateBattleWinner.LEFT
                margin = rightDisplayed - leftDisplayed
            }
            leftDisplayed != null && rightDisplayed != null -> {
                winner = DateBattleWinner.RIGHT
                margin = leftDisplayed - rightDisplayed
            }
            leftDisplayed != null -> {
                winner = DateBattleWinner.LEFT
                margin = null
            }
            rightDisplayed != null -> {
                winner = DateBattleWinner.RIGHT
                margin = null
            }
            else -> {
                winner = DateBattleWinner.TIE
                margin = null
            }
        }

        return DateBattleResult(
            left = left,
            right = right,
            winner = winner,
            winningMargin = margin,
            verdict = PiDelightCopy.verdict(featured, left, right, margin)
        )
    }

    fun shareText(style: ShareCardStyle): String {
        val date = _selectedDate.value.format(DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault()))
        val best = _lookupSummary.value?.bestMatch
        val featured = _featuredNumber.value
        val positions = repository.stats(featured)?.bestDatePositions.orEmpty()
        val symbol = featured.heatMapSymbol

        return when (style) {
            ShareCardStyle.CLASSIC -> {
                if (best != null) {
                    "$date appears in $symbol as ${best.format.displayName} ${best.query} at digit ${displayedPosition(best.storedPosition).formattedNumber()}."
                } else {
                    "$date doesn't appear as an exact ${searchPreference.summary} sequence in the bundled digits of $symbol."
                }
            }
            ShareCardStyle.NERD -> {
                if (best != null) {
                    buildString {
                        appendLine("PiDay Nerd Stats")
                        appendLine("$date")
                        appendLine("Format: ${best.format.displayName}")
                        appendLine("Query: ${best.query}")
                        appendLine("Digit: ${displayedPosition(best.storedPosition).formattedNumber()}")
                        appendLine("Rarity: ${PiDelightCopy.rarityLabel(best.storedPosition, positions)}")
                        selectedDateFunFact?.let { append(it) }
                    }.trim()
                } else {
                    buildString {
                        appendLine("PiDay Nerd Stats")
                        appendLine("$date has no exact hit in the current search formats.")
                        selectedDateFunFact?.let { append(it) }
                    }.trim()
                }
            }
            ShareCardStyle.BATTLE -> "Use the Date Battle sheet to share a head-to-head result."
        }
    }

    private fun scheduleRefresh() {
        lookupJob?.cancel()
        lookupJob = viewModelScope.launch {
            delay(50)
            refreshLookup()
        }
    }

    private suspend fun refreshLookup() {
        _lookupSummary.value = repository.summary(_featuredNumber.value, _selectedDate.value, searchPreference.formats)
    }

    fun refreshDaySummaries() {
        viewModelScope.launch {
            val month = _displayedMonth.value
            val selected = _selectedDate.value

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
        val formats = searchPreference.formats
        val featured = _featuredNumber.value
        val range = repository.indexedYearRange(featured)
        val firstDay = month.atDay(1)
        val lastDay = month.atEndOfMonth()
        val startOffset = firstDay.dayOfWeek.value % 7
        val days = mutableListOf<LocalDate>()
        repeat(startOffset) { i -> days.add(firstDay.minusDays((startOffset - i).toLong())) }
        var day = firstDay
        while (!day.isAfter(lastDay)) {
            days.add(day)
            day = day.plusDays(1)
        }
        while (days.size % 7 != 0) {
            days.add(days.last().plusDays(1))
        }

        return days.map { date ->
            val bundled = repository.summary(featured, date, formats)
            DaySummary(
                date = date,
                dayNumber = date.dayOfMonth,
                isoDate = generator.isoDateString(date),
                isSelected = date == selected,
                isInDisplayedMonth = date.month == month.month,
                isInBundledRange = range?.contains(date.year) == true,
                bestStoredPosition = bundled.bestMatch?.storedPosition,
                foundFormats = bundled.foundCount
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
