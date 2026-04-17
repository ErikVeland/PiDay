package academy.glasscode.piday.features.detail

import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onOpenPreferences: () -> Unit,
    onOpenSavedDates: () -> Unit,
    onOpenBattle: () -> Unit,
    onOpenShare: () -> Unit
) {
    val selectedDate   by vm.selectedDate.collectAsStateWithLifecycle()
    val lookupSummary  by vm.lookupSummary.collectAsStateWithLifecycle()
    val isLoading      by vm.isLoading.collectAsStateWithLifecycle()
    val featured       by vm.featuredNumber.collectAsStateWithLifecycle()
    val convention     = vm.indexingConvention
    val formatter      = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

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
                        vm.toggleSaveCurrentDate()
                    }) {
                        Icon(
                            if (vm.isCurrentDateSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
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
                        val symbol = featured.heatMapSymbol

                        Text(
                            "Position $displayPos",
                            color = palette.accent,
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(symbol, color = palette.onBackground.copy(alpha = 0.55f), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(4.dp))
                        Text("Best format: ${best.format.displayName}", color = palette.onBackground.copy(alpha = 0.7f))
                        Text(best.query, color = palette.onBackground, fontFamily = FontFamily.Monospace)
                    } else {
                        Text(
                            "Not found in bundled digits",
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
                    onClick = onOpenShare,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.accent)
                ) {
                    Icon(Icons.Default.Share, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Share")
                }
                OutlinedButton(
                    onClick = onOpenBattle,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.accent)
                ) {
                    Icon(Icons.Default.Bolt, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Battle")
                }
            }

            Spacer(Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onOpenSavedDates,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.accent)
                ) {
                    Icon(Icons.Default.Bookmark, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Saved")
                }
            }

            vm.selectedDateFunFact?.let { fact ->
                Spacer(Modifier.height(16.dp))
                Text(
                    fact,
                    style = MaterialTheme.typography.bodyMedium,
                    color = palette.accent
                )
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}
