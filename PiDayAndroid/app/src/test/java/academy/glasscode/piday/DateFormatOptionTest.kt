package academy.glasscode.piday

import academy.glasscode.piday.core.domain.DateFormatOption
import org.junit.Assert.assertEquals
import org.junit.Test

class DateFormatOptionTest {

    @Test fun displayNames() {
        assertEquals("YYYYMMDD", DateFormatOption.YYYYMMDD.displayName)
        assertEquals("DDMMYYYY", DateFormatOption.DDMMYYYY.displayName)
        assertEquals("MMDDYYYY", DateFormatOption.MMDDYYYY.displayName)
        assertEquals("YYMMDD",   DateFormatOption.YYMMDD.displayName)
        assertEquals("D/M/YYYY", DateFormatOption.DMY_NO_LEADING_ZEROS.displayName)
    }

    @Test fun queryPartsYyyymmdd() {
        val parts = DateFormatOption.YYYYMMDD.queryParts("20260314")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsDdmmyyyy() {
        val parts = DateFormatOption.DDMMYYYY.queryParts("14032026")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsMmddyyyy() {
        val parts = DateFormatOption.MMDDYYYY.queryParts("03142026")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsYymmdd() {
        val parts = DateFormatOption.YYMMDD.queryParts("260314")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("26", parts.year)
    }

    @Test fun queryPartsDmyNoLeadingZerosSingleDigitDay() {
        // March 3 2026 → "332026", day=1 digit
        val parts = DateFormatOption.DMY_NO_LEADING_ZEROS.queryParts("332026", dayDigits = 1)
        assertEquals("3", parts.day)
        assertEquals("3", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsDmyNoLeadingZerosDoubleDigitDay() {
        // March 14 2026 → "1432026", day=2 digits
        val parts = DateFormatOption.DMY_NO_LEADING_ZEROS.queryParts("1432026", dayDigits = 2)
        assertEquals("14", parts.day)
        assertEquals("3", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun allCasesPresent() {
        assertEquals(5, DateFormatOption.entries.size)
    }

    @Test fun fromSerialName() {
        assertEquals(DateFormatOption.YYYYMMDD, DateFormatOption.fromSerialName("yyyymmdd"))
        assertEquals(DateFormatOption.DMY_NO_LEADING_ZEROS, DateFormatOption.fromSerialName("dmyNoLeadingZeros"))
        assertEquals(null, DateFormatOption.fromSerialName("unknown"))
    }
}
