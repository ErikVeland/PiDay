package academy.glasscode.piday.core.domain

enum class IndexingConvention {
    ONE_BASED, ZERO_BASED;

    val label: String get() = when (this) {
        ONE_BASED  -> "1-based"
        ZERO_BASED -> "0-based"
    }

    val explainer: String get() = when (this) {
        ONE_BASED  -> "Digit 1 is the first digit after the decimal point."
        ZERO_BASED -> "Digit 0 is the first digit after the decimal point."
    }

    fun displayPosition(storedPosition: Int): Int = when (this) {
        ONE_BASED  -> storedPosition
        ZERO_BASED -> storedPosition - 1
    }
}
