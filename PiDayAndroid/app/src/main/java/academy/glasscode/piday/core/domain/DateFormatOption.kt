package academy.glasscode.piday.core.domain

// WHY: Mirrors iOS DateFormatOption exactly. serialName matches the raw value
// used as keys in the bundled JSON index file.
enum class DateFormatOption(val serialName: String) {
    YYYYMMDD("yyyymmdd"),
    DDMMYYYY("ddmmyyyy"),
    MMDDYYYY("mmddyyyy"),
    YYMMDD("yymmdd"),
    DMY_NO_LEADING_ZEROS("dmyNoLeadingZeros");

    val displayName: String get() = when (this) {
        YYYYMMDD             -> "YYYYMMDD"
        DDMMYYYY             -> "DDMMYYYY"
        MMDDYYYY             -> "MMDDYYYY"
        YYMMDD               -> "YYMMDD"
        DMY_NO_LEADING_ZEROS -> "D/M/YYYY"
    }

    val description: String get() = when (this) {
        YYYYMMDD             -> "Canonical ISO-style calendar order."
        DDMMYYYY             -> "Day-first format common outside the US."
        MMDDYYYY             -> "Month-first format common in the US."
        YYMMDD               -> "Compact six-digit version."
        DMY_NO_LEADING_ZEROS -> "Digits only, no leading zeros."
    }

    data class QueryParts(val day: String, val month: String, val year: String)

    // WHY dayDigits param: for D/M/YYYY the split is ambiguous without knowing
    // whether the day is 1 or 2 digits. Pass 1 for days 1–9, 2 for 10–31.
    fun queryParts(query: String, dayDigits: Int = 2): QueryParts = when (this) {
        YYYYMMDD -> if (query.length >= 8) QueryParts(
            day   = query.substring(6, 8),
            month = query.substring(4, 6),
            year  = query.substring(0, 4)
        ) else QueryParts("", "", query)

        DDMMYYYY -> if (query.length >= 8) QueryParts(
            day   = query.substring(0, 2),
            month = query.substring(2, 4),
            year  = query.substring(4)
        ) else QueryParts(query, "", "")

        MMDDYYYY -> if (query.length >= 8) QueryParts(
            day   = query.substring(2, 4),
            month = query.substring(0, 2),
            year  = query.substring(4)
        ) else QueryParts(query, "", "")

        YYMMDD -> if (query.length >= 6) QueryParts(
            day   = query.substring(4, 6),
            month = query.substring(2, 4),
            year  = query.substring(0, 2)
        ) else QueryParts("", "", query)

        DMY_NO_LEADING_ZEROS -> if (query.length < 5) {
            QueryParts(query, "", "")
        } else {
            val yearPart  = query.takeLast(4)
            val dayMonth  = query.dropLast(4)
            val clampedLen = dayDigits.coerceIn(1, (dayMonth.length - 1).coerceAtLeast(1))
            QueryParts(
                day   = dayMonth.take(clampedLen),
                month = dayMonth.drop(clampedLen),
                year  = yearPart
            )
        }
    }

    companion object {
        fun fromSerialName(name: String): DateFormatOption? =
            entries.firstOrNull { it.serialName == name }
    }
}
