package academy.glasscode.piday.features.battle

import academy.glasscode.piday.core.domain.DateBattleResult
import academy.glasscode.piday.core.domain.PiDelightCopy
import academy.glasscode.piday.core.domain.formattedNumber
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import android.app.DatePickerDialog
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateBattleSheet(
    vm: AppViewModel,
    palette: AppPalette,
    anchorDate: LocalDate,
    initialOpponent: LocalDate = anchorDate.plusDays(1),
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val formatter = remember { DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault()) }
    var opponentDate by remember { mutableStateOf(initialOpponent) }
    var battle by remember { mutableStateOf<DateBattleResult?>(null) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(anchorDate, opponentDate) {
        isLoading = true
        battle = withContext(Dispatchers.IO) {
            vm.compareDates(anchorDate, opponentDate)
        }
        isLoading = false
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Date Battle", style = MaterialTheme.typography.titleLarge, color = palette.onBackground)
            Spacer(Modifier.height(8.dp))
            Text(
                "Pit the selected date against any rival. Pi will choose only one.",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.onBackground.copy(alpha = 0.7f)
            )

            Spacer(Modifier.height(16.dp))

            Text("Selected date", style = MaterialTheme.typography.labelLarge, color = palette.onBackground.copy(alpha = 0.6f))
            Text(anchorDate.format(formatter), style = MaterialTheme.typography.titleMedium, color = palette.onBackground)

            Spacer(Modifier.height(12.dp))

            Button(
                onClick = {
                    showDatePicker(context, opponentDate) { picked -> opponentDate = picked }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Choose challenger: ${opponentDate.format(formatter)}")
            }

            Spacer(Modifier.height(18.dp))

            when {
                isLoading -> Text("Comparing dates…", color = palette.onBackground.copy(alpha = 0.7f))
                battle != null -> BattleResultContent(battle = battle!!, palette = palette)
            }

            battle?.let { result ->
                Spacer(Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = { shareText(context, "PiDay Battle", PiDelightCopy.battleShareText(result)) }) {
                        Text("Share Battle")
                    }
                    OutlinedButton(onClick = { opponentDate = anchorDate.plusDays(1) }) {
                        Text("Reset")
                    }
                }
            }

            Spacer(Modifier.height(28.dp))
        }
    }
}

@Composable
private fun BattleResultContent(
    battle: DateBattleResult,
    palette: AppPalette
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Verdict", style = MaterialTheme.typography.labelLarge, color = palette.onBackground.copy(alpha = 0.6f))
        Text(battle.verdict, style = MaterialTheme.typography.titleMedium, color = palette.onBackground)

        if (battle.hasWinner && battle.winningMargin != null) {
            Text(
                "Winning margin: ${battle.winningMargin.formattedNumber()} digits",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.accent
            )
        }

        BattleContenderCard("Selected date", battle.left, palette)
        BattleContenderCard("Challenger", battle.right, palette)
    }
}

@Composable
private fun BattleContenderCard(
    title: String,
    contender: academy.glasscode.piday.core.domain.DateBattleContender,
    palette: AppPalette
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = palette.onBackground.copy(alpha = 0.6f))
        Text(contender.date.toString(), style = MaterialTheme.typography.titleSmall, color = palette.onBackground)
        if (contender.bestMatch != null && contender.displayedPosition != null) {
            Text(
                "${contender.bestMatch.format.displayName} ${contender.bestMatch.query}",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.onBackground
            )
            Text(
                "Digit ${contender.displayedPosition.formattedNumber()} • ${contender.percentileLabel}",
                style = MaterialTheme.typography.bodySmall,
                color = palette.accent
            )
        } else if (contender.summary.errorMessage != null) {
            Text(contender.summary.errorMessage, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        } else {
            Text("No exact hit in the active search formats.", style = MaterialTheme.typography.bodySmall, color = palette.onBackground.copy(alpha = 0.7f))
        }
    }
}

private fun showDatePicker(context: Context, current: LocalDate, onDate: (LocalDate) -> Unit) {
    DatePickerDialog(
        context,
        { _, year, month, dayOfMonth -> onDate(LocalDate.of(year, month + 1, dayOfMonth)) },
        current.year,
        current.monthValue - 1,
        current.dayOfMonth
    ).show()
}

private fun shareText(context: Context, title: String, body: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, title)
        putExtra(Intent.EXTRA_TEXT, body)
    }
    context.startActivity(Intent.createChooser(intent, title))
}
