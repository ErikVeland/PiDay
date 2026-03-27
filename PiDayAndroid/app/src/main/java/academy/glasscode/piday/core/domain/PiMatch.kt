package academy.glasscode.piday.core.domain

data class PiMatchResult(
    val query: String,
    val format: DateFormatOption,
    val found: Boolean,
    val storedPosition: Int?,
    val excerpt: String?
) {
    companion object {
        // WHY: Matches with a position sort before those without; ties sort by format name.
        val byPosition: Comparator<PiMatchResult> = Comparator { l, r ->
            when {
                l.storedPosition != null && r.storedPosition != null -> l.storedPosition - r.storedPosition
                l.storedPosition != null -> -1
                r.storedPosition != null ->  1
                else -> l.format.displayName.compareTo(r.format.displayName)
            }
        }
    }
}

data class BestPiMatch(
    val format: DateFormatOption,
    val query: String,
    val storedPosition: Int,
    val excerpt: String
) {
    companion object {
        // WHY preferPadded: shorter strings (D/M/YYYY) match more often by chance.
        // Users recognise "14032026" as their birthday; "1432026" looks like a bug.
        val preferringPadded: Comparator<BestPiMatch> = Comparator { l, r ->
            val lPadded = l.format != DateFormatOption.DMY_NO_LEADING_ZEROS
            val rPadded = r.format != DateFormatOption.DMY_NO_LEADING_ZEROS
            when {
                lPadded != rPadded -> if (lPadded) -1 else 1
                else               -> l.storedPosition - r.storedPosition
            }
        }
    }
}

enum class LookupSource { BUNDLED, LIVE }

data class DateLookupSummary(
    val isoDate: String,
    val matches: List<PiMatchResult>,
    val bestMatch: BestPiMatch?,
    val source: LookupSource,
    val errorMessage: String?
) {
    val foundCount: Int get() = matches.count { it.found }
}
