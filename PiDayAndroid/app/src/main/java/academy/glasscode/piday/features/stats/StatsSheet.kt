package academy.glasscode.piday.features.stats

import academy.glasscode.piday.core.domain.PiStats
import academy.glasscode.piday.core.domain.formattedNumber
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit
) {
    val selectedDate by vm.selectedDate.collectAsStateWithLifecycle()
    val summary by vm.lookupSummary.collectAsStateWithLifecycle()
    val featured by vm.featuredNumber.collectAsStateWithLifecycle()
    val stats = vm.stats
    val formatter = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(
            modifier = Modifier
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("Nerdy Stats", style = MaterialTheme.typography.titleLarge, color = palette.onBackground)

            if (stats == null) {
                Text("Stats are still loading from the bundled index.", color = palette.onBackground.copy(alpha = 0.7f))
            } else {
                StatsCard(
                    title = "Selected Date",
                    lines = buildList {
                        add(selectedDate.format(formatter))
                        summary?.bestMatch?.let { best ->
                            add("Best format: ${best.format.displayName}")
                            add("Digit: ${vm.displayedPosition(best.storedPosition).formattedNumber()}")
                            add("Rarity: ${academy.glasscode.piday.core.domain.PiDelightCopy.rarityLabel(best.storedPosition, stats.bestDatePositions)}")
                        } ?: add("No exact hit in the active search formats")
                        vm.selectedDateFunFact?.let(::add)
                    },
                    palette = palette
                )

                StatsCard(
                    title = "Hall of Fame",
                    lines = stats.topEarliestDates.mapIndexed { index, match ->
                        "#${index + 1} ${match.date} • ${match.format.displayName} • digit ${vm.displayedPosition(match.position).formattedNumber()}"
                    },
                    palette = palette
                )

                StatsCard(
                    title = "Records",
                    lines = buildList {
                        stats.earliestMatch?.let { add("Earliest: ${it.date} at digit ${vm.displayedPosition(it.position).formattedNumber()}") }
                        stats.latestMatch?.let { add("Latest: ${it.date} at digit ${vm.displayedPosition(it.position).formattedNumber()}") }
                        stats.luckiestMonth?.let { add("Luckiest month: ${monthName(it.month)}") }
                        stats.hardestMonth?.let { add("Hardest month: ${monthName(it.month)}") }
                        stats.luckiestDayOfMonth?.let { add("Luckiest day-of-month: ${it.day}") }
                        stats.hardestDayOfMonth?.let { add("Hardest day-of-month: ${it.day}") }
                    },
                    palette = palette
                )

                StatsCard(
                    title = "Format Lab",
                    lines = buildList {
                        stats.formatSuccessRate.entries.sortedBy { it.value }.forEach { entry ->
                            add("${entry.key.displayName}: avg digit ${vm.displayedPosition(entry.value.toInt()).formattedNumber()}")
                        }
                        stats.biggestFormatUpset?.let {
                            add("Biggest upset: ${it.date} swings from ${it.bestFormat.displayName} to ${it.worstFormat.displayName} by ${it.spread.formattedNumber()} digits")
                        }
                    },
                    palette = palette
                )

                StatsCard(
                    title = "Oddities",
                    lines = buildList {
                        stats.longestRepeatRun?.let {
                            add("Longest repeated run: ${it.query} (${it.score} in a row)")
                        }
                        stats.mostUniqueDigits?.let {
                            add("Most unique digits: ${it.query} (${it.score} unique digits)")
                        }
                        add("Bundled dates indexed: ${stats.totalDatesMatched.formattedNumber()}")
                        add("Deepest digit reached: ${vm.displayedPosition(stats.maxDigitReached).formattedNumber()}")
                    },
                    palette = palette
                )

                StatsCard(
                    title = "${featured.title} Day Special (${featured.observedDayLabel})",
                    lines = stats.piDayStats.entries.sortedBy { it.key }.map { (year, position) ->
                        "$year: digit ${vm.displayedPosition(position).formattedNumber()}"
                    },
                    palette = palette
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun StatsCard(
    title: String,
    lines: List<String>,
    palette: AppPalette
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = palette.accent)
        lines.forEach { line ->
            Text(line, style = MaterialTheme.typography.bodyMedium, color = palette.onBackground)
        }
    }
}

private fun monthName(month: Int): String = when (month) {
    1 -> "January"
    2 -> "February"
    3 -> "March"
    4 -> "April"
    5 -> "May"
    6 -> "June"
    7 -> "July"
    8 -> "August"
    9 -> "September"
    10 -> "October"
    11 -> "November"
    12 -> "December"
    else -> "Unknown"
}
