package academy.glasscode.piday

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.DateFormatOption
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class DateStringGeneratorTest {
    private val gen   = DateStringGenerator()
    private val piDay = LocalDate.of(2026, 3, 14)  // Pi Day 2026

    @Test fun yyyymmdd() {
        val result = gen.strings(piDay, listOf(DateFormatOption.YYYYMMDD))
        assertEquals(listOf(DateFormatOption.YYYYMMDD to "20260314"), result)
    }

    @Test fun ddmmyyyy() {
        val result = gen.strings(piDay, listOf(DateFormatOption.DDMMYYYY))
        assertEquals(listOf(DateFormatOption.DDMMYYYY to "14032026"), result)
    }

    @Test fun mmddyyyy() {
        val result = gen.strings(piDay, listOf(DateFormatOption.MMDDYYYY))
        assertEquals(listOf(DateFormatOption.MMDDYYYY to "03142026"), result)
    }

    @Test fun yymmdd() {
        val result = gen.strings(piDay, listOf(DateFormatOption.YYMMDD))
        assertEquals(listOf(DateFormatOption.YYMMDD to "260314"), result)
    }

    @Test fun dmyNoLeadingZeros() {
        val result = gen.strings(piDay, listOf(DateFormatOption.DMY_NO_LEADING_ZEROS))
        assertEquals(listOf(DateFormatOption.DMY_NO_LEADING_ZEROS to "1432026"), result)
    }

    @Test fun singleDigitDayNoLeadingZeros() {
        // March 3 → "332026"
        val march3 = LocalDate.of(2026, 3, 3)
        val result = gen.strings(march3, listOf(DateFormatOption.DMY_NO_LEADING_ZEROS))
        assertEquals(listOf(DateFormatOption.DMY_NO_LEADING_ZEROS to "332026"), result)
    }

    @Test fun isoDateString() {
        assertEquals("2026-03-14", gen.isoDateString(piDay))
    }

    @Test fun allFormatsReturned() {
        val result = gen.strings(piDay, DateFormatOption.entries)
        assertEquals(5, result.size)
    }
}
