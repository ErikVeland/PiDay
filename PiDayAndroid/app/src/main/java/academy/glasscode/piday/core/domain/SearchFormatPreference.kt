package academy.glasscode.piday.core.domain

enum class SearchFormatPreference {
    INTERNATIONAL, AMERICAN, ISO8601, ALL;

    val label: String get() = when (this) {
        INTERNATIONAL -> "DD/MM"
        AMERICAN      -> "MM/DD"
        ISO8601       -> "ISO"
        ALL           -> "All"
    }

    val title: String get() = when (this) {
        INTERNATIONAL -> "International"
        AMERICAN      -> "American"
        ISO8601       -> "ISO 8601"
        ALL           -> "Indexed Formats"
    }

    val formats: List<DateFormatOption> get() = when (this) {
        INTERNATIONAL -> listOf(DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS)
        AMERICAN      -> listOf(DateFormatOption.MMDDYYYY)
        ISO8601       -> listOf(DateFormatOption.YYYYMMDD)
        ALL           -> listOf(
            DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS,
            DateFormatOption.MMDDYYYY, DateFormatOption.YYYYMMDD, DateFormatOption.YYMMDD
        )
    }

    val heroFormat: DateFormatOption get() = when (this) {
        INTERNATIONAL, ALL -> DateFormatOption.DDMMYYYY
        AMERICAN           -> DateFormatOption.MMDDYYYY
        ISO8601            -> DateFormatOption.YYYYMMDD
    }

    val summary: String get() = when (this) {
        INTERNATIONAL -> "DDMMYYYY or D/M/YYYY"
        AMERICAN      -> "MMDDYYYY"
        ISO8601       -> "YYYYMMDD"
        ALL           -> "any indexed format"
    }
}
