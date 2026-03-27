package academy.glasscode.piday.services

import academy.glasscode.piday.core.domain.SavedDate
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.savedDatesDataStore: DataStore<Preferences> by preferencesDataStore("saved_dates")

class SavedDatesStore(private val context: Context) {
    private val key  = stringPreferencesKey("saved_dates_json")
    private val json = Json { ignoreUnknownKeys = true }

    val savedDates: Flow<List<SavedDate>> = context.savedDatesDataStore.data.map { prefs ->
        prefs[key]?.let {
            runCatching { json.decodeFromString<List<SavedDate>>(it) }.getOrElse { emptyList() }
        } ?: emptyList()
    }

    suspend fun save(dates: List<SavedDate>) {
        context.savedDatesDataStore.edit { it[key] = json.encodeToString(dates) }
    }
}
