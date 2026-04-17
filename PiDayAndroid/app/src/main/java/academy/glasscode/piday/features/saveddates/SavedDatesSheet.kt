package academy.glasscode.piday.features.saveddates

import academy.glasscode.piday.core.domain.RankedSavedDate
import academy.glasscode.piday.core.domain.SavedDate
import academy.glasscode.piday.core.domain.SavedDatesSortOption
import academy.glasscode.piday.core.domain.formattedNumber
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.battle.DateBattleSheet
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SavedDatesSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onDateSelected: (java.time.LocalDate) -> Unit
) {
    val formatter   = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())
    val savedDates by vm.savedDates.collectAsStateWithLifecycle()
    val currentSelectedDate by vm.selectedDate.collectAsStateWithLifecycle()
    var sortOption by remember { mutableStateOf(SavedDatesSortOption.BEST_POSITION) }
    var editingDate by remember { mutableStateOf<SavedDate?>(null) }
    var labelDraft by remember { mutableStateOf("") }
    var battlingDate by remember { mutableStateOf<SavedDate?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(horizontal = 24.dp)) {
            Text("Saved Dates", style = MaterialTheme.typography.titleLarge, color = palette.onBackground)
            Spacer(Modifier.height(16.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SavedDatesSortOption.entries.forEach { option ->
                    FilterChip(
                        selected = sortOption == option,
                        onClick = { sortOption = option },
                        label = { Text(option.title) }
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            if (savedDates.isEmpty()) {
                Text(
                    "No saved dates yet. Tap the bookmark icon on any date.",
                    color = palette.onBackground.copy(alpha = 0.5f)
                )
            } else {
                val rankedDates = vm.rankedSavedDates(sortOption)
                LazyColumn {
                    items(rankedDates, key = { it.savedDate.id }) { ranked ->
                        RankedSavedDateRow(
                            ranked = ranked,
                            formatter = formatter,
                            palette = palette,
                            onSelect = {
                                onDateSelected(ranked.savedDate.date)
                                onDismiss()
                            },
                            onBattle = { battlingDate = ranked.savedDate },
                            onEdit = {
                                editingDate = ranked.savedDate
                                labelDraft = ranked.savedDate.label
                            },
                            onDelete = { vm.deleteSavedDate(ranked.savedDate.id) }
                        )
                        HorizontalDivider(color = palette.border)
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }

    editingDate?.let { saved ->
        AlertDialog(
            onDismissRequest = { editingDate = null },
            title = { Text("Edit Label") },
            text = {
                Column {
                    Text(saved.date.format(formatter), style = MaterialTheme.typography.bodySmall)
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = labelDraft,
                        onValueChange = { labelDraft = it },
                        label = { Text("Label") }
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        vm.updateSavedDateLabel(saved.id, labelDraft)
                        editingDate = null
                    }
                ) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { editingDate = null }) { Text("Cancel") }
            }
        )
    }

    battlingDate?.let { saved ->
        DateBattleSheet(
            vm = vm,
            palette = palette,
            anchorDate = currentSelectedDate,
            initialOpponent = saved.date,
            onDismiss = { battlingDate = null }
        )
    }
}

@Composable
private fun RankedSavedDateRow(
    ranked: RankedSavedDate,
    formatter: DateTimeFormatter,
    palette: AppPalette,
    onSelect: () -> Unit,
    onBattle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f).clickable(onClick = onSelect)
        ) {
            val subtitle = buildList {
                ranked.bestStoredPosition?.let { add("digit ${it.formattedNumber()}") }
                ranked.percentileLabel?.let(::add)
                ranked.bestFormat?.let { add(it.displayName) }
            }.joinToString(" • ")
            Text(
                buildString {
                    ranked.rank?.let { append("#$it ") }
                    append(ranked.savedDate.label)
                },
                color = palette.onBackground
            )
            Text(
                ranked.savedDate.date.format(formatter),
                color = palette.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall
            )
            if (subtitle.isNotBlank()) {
                Text(
                    subtitle,
                    color = palette.accent,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        IconButton(onClick = onBattle) {
            Icon(Icons.Default.FlashOn, "Battle", tint = palette.accent)
        }
        IconButton(onClick = onEdit) {
            Icon(Icons.Default.Edit, "Edit", tint = palette.accent)
        }
        IconButton(onClick = onDelete) {
            Icon(Icons.Default.Delete, "Delete", tint = MaterialTheme.colorScheme.error)
        }
    }
}
