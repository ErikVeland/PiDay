package academy.glasscode.piday.features.freesearch

import academy.glasscode.piday.core.repository.PiLiveLookupService
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class FreeSearchViewModel : ViewModel() {
    private val liveLookup  = PiLiveLookupService()

    private val _result     = MutableStateFlow<Pair<Int, String>?>(null)
    val result: StateFlow<Pair<Int, String>?> = _result.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _error      = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private var searchJob: Job? = null

    // WHY 400ms debounce: mirrors iOS FreeSearchViewModel — avoids hammering the API
    // on every keystroke while keeping the UX snappy.
    fun onQueryChange(query: String) {
        searchJob?.cancel()
        if (query.length < 2) {
            _result.value = null
            _error.value  = null
            return
        }
        searchJob = viewModelScope.launch {
            delay(400)
            if (!isActive) return@launch
            _isSearching.value = true
            _error.value       = null
            try {
                _result.value = liveLookup.searchDigits(query)
            } catch (e: Exception) {
                _error.value = e.message ?: "Search failed"
            } finally {
                _isSearching.value = false
            }
        }
    }

    fun clear() {
        searchJob?.cancel()
        _result.value      = null
        _error.value       = null
        _isSearching.value = false
    }
}
