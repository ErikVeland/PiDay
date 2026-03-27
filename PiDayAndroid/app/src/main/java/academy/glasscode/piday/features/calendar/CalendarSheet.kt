package academy.glasscode.piday.features.calendar

import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarSheet(vm: AppViewModel, palette: AppPalette, onDismiss: () -> Unit) {
    val displayedMonth by vm.displayedMonth.collectAsStateWithLifecycle()
    val daySummaries   by vm.daySummaries.collectAsStateWithLifecycle()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor   = palette.background
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            // Month navigation header
            Row(
                modifier                  = Modifier.fillMaxWidth(),
                horizontalArrangement     = Arrangement.SpaceBetween,
                verticalAlignment         = Alignment.CenterVertically
            ) {
                IconButton(onClick = { vm.setDisplayedMonth(displayedMonth.minusMonths(1)) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Previous month", tint = palette.accent)
                }
                Text(
                    text  = "${displayedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${displayedMonth.year}",
                    color = palette.onBackground,
                    style = MaterialTheme.typography.titleMedium
                )
                IconButton(onClick = { vm.setDisplayedMonth(displayedMonth.plusMonths(1)) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, "Next month", tint = palette.accent)
                }
            }

            // Weekday symbols
            Row(modifier = Modifier.fillMaxWidth()) {
                listOf("S","M","T","W","T","F","S").forEach { sym ->
                    Text(
                        text      = sym,
                        modifier  = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        color     = palette.onBackground.copy(alpha = 0.5f),
                        fontSize  = 12.sp
                    )
                }
            }
            Spacer(Modifier.height(4.dp))

            LazyVerticalGrid(columns = GridCells.Fixed(7), modifier = Modifier.fillMaxWidth()) {
                items(daySummaries) { summary ->
                    DayCell(
                        summary  = summary,
                        isToday  = summary.date == vm.today,
                        palette  = palette,
                        onClick  = {
                            vm.selectDate(summary.date)
                            onDismiss()
                        }
                    )
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun DayCell(
    summary: DaySummary,
    isToday: Boolean,
    palette: AppPalette,
    onClick: () -> Unit
) {
    val heatColor = when (summary.heatLevel) {
        PiHeatLevel.NONE  -> palette.heatNone
        PiHeatLevel.FAINT -> palette.heatFaint
        PiHeatLevel.COOL  -> palette.heatCool
        PiHeatLevel.WARM  -> palette.heatWarm
        PiHeatLevel.HOT   -> palette.heatHot
    }

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .clip(CircleShape)
            .background(if (summary.isInBundledRange && summary.isInDisplayedMonth) heatColor else Color.Transparent)
            .clickable(enabled = summary.isInDisplayedMonth) { onClick() }
    ) {
        if (summary.isSelected) {
            Box(
                modifier = Modifier
                    .fillMaxSize(0.82f)
                    .clip(CircleShape)
                    .background(palette.accent)
            )
        }
        Text(
            text       = if (summary.isInDisplayedMonth) summary.dayNumber.toString() else "",
            color      = when {
                summary.isSelected          -> Color.White
                !summary.isInDisplayedMonth -> Color.Transparent
                isToday                     -> palette.accent
                else                        -> palette.onBackground
            },
            fontSize   = 13.sp,
            fontWeight = if (summary.isSelected || isToday) FontWeight.Bold else FontWeight.Normal
        )
    }
}
