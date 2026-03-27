package academy.glasscode.piday.services

import academy.glasscode.piday.core.domain.IndexingConvention
import academy.glasscode.piday.core.domain.SearchFormatPreference
import academy.glasscode.piday.design.AppThemeOption
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.prefDataStore: DataStore<Preferences> by preferencesDataStore("piday_prefs")

// WHY DataStore: replaces iOS UserDefaults. It's fully async and coroutine-friendly,
// avoiding main-thread I/O that SharedPreferences can cause.
class PreferencesStore(private val context: Context) {
    companion object {
        val KEY_THEME       = stringPreferencesKey("theme")
        val KEY_FORMAT_PREF = stringPreferencesKey("format_pref")
        val KEY_INDEXING    = stringPreferencesKey("indexing")
    }

    val themeFlow: Flow<AppThemeOption> = context.prefDataStore.data.map { prefs ->
        prefs[KEY_THEME]?.let { runCatching { AppThemeOption.valueOf(it) }.getOrNull() }
            ?: AppThemeOption.SLATE
    }

    val formatPrefFlow: Flow<SearchFormatPreference> = context.prefDataStore.data.map { prefs ->
        prefs[KEY_FORMAT_PREF]?.let { runCatching { SearchFormatPreference.valueOf(it) }.getOrNull() }
            ?: SearchFormatPreference.INTERNATIONAL
    }

    val indexingFlow: Flow<IndexingConvention> = context.prefDataStore.data.map { prefs ->
        prefs[KEY_INDEXING]?.let { runCatching { IndexingConvention.valueOf(it) }.getOrNull() }
            ?: IndexingConvention.ONE_BASED
    }

    suspend fun setTheme(theme: AppThemeOption) {
        context.prefDataStore.edit { it[KEY_THEME] = theme.name }
    }

    suspend fun setFormatPreference(pref: SearchFormatPreference) {
        context.prefDataStore.edit { it[KEY_FORMAT_PREF] = pref.name }
    }

    suspend fun setIndexingConvention(convention: IndexingConvention) {
        context.prefDataStore.edit { it[KEY_INDEXING] = convention.name }
    }
}
