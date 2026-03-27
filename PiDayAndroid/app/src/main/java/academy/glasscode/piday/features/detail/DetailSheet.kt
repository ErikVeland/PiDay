package academy.glasscode.piday.features.detail

import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import academy.glasscode.piday.services.SavedDatesStore
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onOpenPreferences: () -> Unit,
    onOpenFreeSearch: () -> Unit,
    onOpenSavedDates: () -> Unit
) {
    val selectedDate   by vm.selectedDate.collectAsStateWithLifecycle()
    val lookupSummary  by vm.lookupSummary.collectAsStateWithLifecycle()
    val isLoading      by vm.isLoading.collectAsStateWithLifecycle()
    val convention     = vm.indexingConvention
    val context        = LocalContext.current
    val savedDatesStore = remember { SavedDatesStore(context) }
    val scope          = rememberCoroutineScope()
    val formatter      = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    var isBookmarked by remember { mutableStateOf(false) }
    LaunchedEffect(selectedDate) {
        savedDatesStore.savedDates.collectLatest { dates ->
            isBookmarked = dates.any { it.matches(selectedDate) }
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Header row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text  = selectedDate.format(formatter),
                    style = MaterialTheme.typography.headlineSmall,
                    color = palette.onBackground
                )
                Row {
                    IconButton(onClick = {
                        scope.launch {
                            savedDatesStore.savedDates.collectLatest { current ->
                                if (isBookmarked) {
                                    savedDatesStore.save(current.filter { !it.matches(selectedDate) })
                                } else {
                                    val label = selectedDate.format(DateTimeFormatter.ofPattern("MMM d yyyy"))
                                    val newDate = academy.glasscode.piday.core.domain.SavedDate.from(selectedDate, label)
                                    savedDatesStore.save(current + newDate)
                                }
                                return@collectLatest
                            }
                        }
                    }) {
                        Icon(
                            if (isBookmarked) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            "Bookmark",
                            tint = palette.accent
                        )
                    }
                    IconButton(onClick = onOpenPreferences) {
                        Icon(Icons.Default.Settings, "Settings", tint = palette.accent)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            when {
                isLoading -> CircularProgressIndicator(color = palette.accent)
                lookupSummary == null -> Text("Loading…", color = palette.onBackground.copy(alpha = 0.5f))
                else -> {
                    val summary = lookupSummary!!
                    if (summary.bestMatch != null) {
                        val best       = summary.bestMatch
                        val displayPos = convention.displayPosition(best.storedPosition)
                        val sourceLabel = if (summary.source == academy.glasscode.piday.core.domain.LookupSource.LIVE) " (live)" else ""

                        Text(
                            "Position $displayPos$sourceLabel",
                            color = palette.accent,
                            style = MaterialTheme.typography.titleLarge
                        )
                        Spacer(Modifier.height(4.dp))
                        Text("Best format: ${best.format.displayName}", color = palette.onBackground.copy(alpha = 0.7f))
                        Text(best.query, color = palette.onBackground, fontFamily = FontFamily.Monospace)
                    } else {
                        Text(
                            "Not found in first 5 billion digits",
                            color = palette.onBackground.copy(alpha = 0.6f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                        summary.errorMessage?.let {
                            Spacer(Modifier.height(4.dp))
                            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                        }
                    }

                    Spacer(Modifier.height(16.dp))
                    HorizontalDivider(color = palette.border)
                    Spacer(Modifier.height(12.dp))

                    // All format results
                    summary.matches.forEach { match ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                match.format.displayName,
                                color = palette.onBackground.copy(alpha = 0.65f),
                                fontFamily = FontFamily.Monospace,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                if (match.found)
                                    match.storedPosition?.let { convention.displayPosition(it).toString() } ?: "–"
                                else "Not found",
                                color = if (match.found) palette.onBackground else palette.onBackground.copy(alpha = 0.35f),
                                fontFamily = FontFamily.Monospace
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onOpenFreeSearch,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.accent)
                ) {
                    Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Search")
                }
                OutlinedButton(
                    onClick = onOpenSavedDates,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.accent)
                ) {
                    Icon(Icons.Default.Bookmark, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Saved")
                }
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}
