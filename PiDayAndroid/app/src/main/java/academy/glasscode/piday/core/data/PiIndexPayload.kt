package academy.glasscode.piday.core.data

import academy.glasscode.piday.core.domain.DateFormatOption
import kotlinx.serialization.Serializable

// WHY: These are DTOs — their only job is decoding the bundled JSON file.
// If the JSON format ever changes, only this file needs updating.
// The "formats" map uses plain String keys because kotlinx.serialization can't
// automatically key a Map by an enum; we convert to DateFormatOption in formatMap().

@Serializable
data class PiFormatMatch(
    val query: String,
    val position: Int,
    val excerpt: String
)

@Serializable
data class PiDateRecord(
    val date: String,
    val formats: Map<String, PiFormatMatch>
) {
    // Converts the raw string-keyed map to a typed DateFormatOption map.
    // Unknown keys (future format additions) are silently skipped.
    fun formatMap(): Map<DateFormatOption, PiFormatMatch> =
        formats.mapNotNull { (key, value) ->
            DateFormatOption.fromSerialName(key)?.let { it to value }
        }.toMap()
}

@Serializable
data class PiIndexMetadata(
    val startYear: Int,
    val endYear: Int,
    val indexing: String,
    val excerptRadius: Int,
    val generatedAt: String,
    val source: String
)

@Serializable
data class PiIndexPayload(
    val metadata: PiIndexMetadata,
    val dates: Map<String, PiDateRecord>   // keyed by "YYYY-MM-DD"
)
