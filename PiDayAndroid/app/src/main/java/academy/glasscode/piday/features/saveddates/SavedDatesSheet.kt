package academy.glasscode.piday.features.saveddates

import academy.glasscode.piday.core.domain.SavedDate
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.services.SavedDatesStore
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SavedDatesSheet(
    palette: AppPalette,
    onDismiss: () -> Unit,
    onDateSelected: (java.time.LocalDate) -> Unit
) {
    val context     = LocalContext.current
    val store       = remember { SavedDatesStore(context) }
    val scope       = rememberCoroutineScope()
    val formatter   = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    var savedDates by remember { mutableStateOf<List<SavedDate>>(emptyList()) }
    LaunchedEffect(Unit) {
        store.savedDates.collectLatest { savedDates = it }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(horizontal = 24.dp)) {
            Text("Saved Dates", style = MaterialTheme.typography.titleLarge, color = palette.onBackground)
            Spacer(Modifier.height(16.dp))

            if (savedDates.isEmpty()) {
                Text(
                    "No saved dates yet. Tap the bookmark icon on any date.",
                    color = palette.onBackground.copy(alpha = 0.5f)
                )
            } else {
                LazyColumn {
                    items(savedDates, key = { it.id }) { saved ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(
                                modifier = Modifier.weight(1f).clickable(onClick = {
                                    onDateSelected(saved.date)
                                    onDismiss()
                                })
                            ) {
                                Text(saved.label, color = palette.onBackground)
                                Text(
                                    saved.date.format(formatter),
                                    color = palette.onBackground.copy(alpha = 0.6f),
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                            IconButton(onClick = {
                                scope.launch {
                                    store.save(savedDates.filter { it.id != saved.id })
                                }
                            }) {
                                Icon(Icons.Default.Delete, "Delete", tint = MaterialTheme.colorScheme.error)
                            }
                        }
                        HorizontalDivider(color = palette.border)
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

// Extension to make Column clickable (needed above)
private fun Modifier.clickable(onClick: () -> Unit): Modifier =
    this.then(androidx.compose.foundation.clickable { onClick() })
