package academy.glasscode.piday.features.preferences

import academy.glasscode.piday.core.domain.IndexingConvention
import academy.glasscode.piday.core.domain.SearchFormatPreference
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.design.PiThemes
import academy.glasscode.piday.features.main.AppViewModel
import academy.glasscode.piday.services.PreferencesStore
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PreferencesScreen(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onThemeChange: (AppThemeOption) -> Unit
) {
    val context     = LocalContext.current
    val prefsStore  = remember { PreferencesStore(context) }
    val scope       = rememberCoroutineScope()

    var selectedTheme by remember { mutableStateOf(AppThemeOption.SLATE) }
    LaunchedEffect(Unit) {
        prefsStore.themeFlow.collectLatest { selectedTheme = it }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        LazyColumn(modifier = Modifier.padding(horizontal = 24.dp)) {

            // Theme swatches
            item {
                Text("Theme", style = MaterialTheme.typography.labelLarge,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(10.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(AppThemeOption.entries.filter { it != AppThemeOption.CUSTOM }) { option ->
                        val swatchPalette = PiThemes.forOption(option)
                        val isSelected = selectedTheme == option
                        Box(
                            modifier = Modifier
                                .size(width = 72.dp, height = 90.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(swatchPalette.background)
                                .then(
                                    if (isSelected) Modifier.border(2.dp, palette.accent, RoundedCornerShape(12.dp))
                                    else Modifier
                                )
                                .clickable {
                                    selectedTheme = option
                                    scope.launch { prefsStore.setTheme(option) }
                                    onThemeChange(option)
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                // Mini colour row: day/month/year dots
                                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                                    listOf(swatchPalette.dayColor, swatchPalette.monthColor, swatchPalette.yearColor)
                                        .forEach { c ->
                                            Box(
                                                Modifier
                                                    .size(10.dp)
                                                    .clip(androidx.compose.foundation.shape.CircleShape)
                                                    .background(c)
                                            )
                                        }
                                }
                                Spacer(Modifier.height(6.dp))
                                Text(
                                    option.name.lowercase().replaceFirstChar { it.uppercase() },
                                    color     = swatchPalette.onBackground,
                                    fontSize  = 11.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
                Spacer(Modifier.height(24.dp))
            }

            // Date format preference
            item {
                Text("Date Format", style = MaterialTheme.typography.labelLarge,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(8.dp))
            }
            items(SearchFormatPreference.entries) { pref ->
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)
                        .clickable {
                            vm.setSearchPreference(pref)
                            scope.launch { prefsStore.setFormatPreference(pref) }
                        },
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(pref.title, color = palette.onBackground)
                        Text(pref.label, color = palette.onBackground.copy(alpha = 0.5f),
                             style = MaterialTheme.typography.bodySmall)
                    }
                    RadioButton(
                        selected = vm.searchPreference == pref,
                        onClick  = {
                            vm.setSearchPreference(pref)
                            scope.launch { prefsStore.setFormatPreference(pref) }
                        },
                        colors = RadioButtonDefaults.colors(selectedColor = palette.accent)
                    )
                }
            }

            item { Spacer(Modifier.height(24.dp)) }

            // Indexing convention
            item {
                Text("Position Display", style = MaterialTheme.typography.labelLarge,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(8.dp))
            }
            items(IndexingConvention.entries) { convention ->
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)
                        .clickable {
                            vm.setIndexingConvention(convention)
                            scope.launch { prefsStore.setIndexingConvention(convention) }
                        },
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(convention.label, color = palette.onBackground)
                        Text(convention.explainer, color = palette.onBackground.copy(alpha = 0.5f),
                             style = MaterialTheme.typography.bodySmall)
                    }
                    RadioButton(
                        selected = vm.indexingConvention == convention,
                        onClick  = {
                            vm.setIndexingConvention(convention)
                            scope.launch { prefsStore.setIndexingConvention(convention) }
                        },
                        colors = RadioButtonDefaults.colors(selectedColor = palette.accent)
                    )
                }
            }

            item {
                Spacer(Modifier.height(24.dp))
                HorizontalDivider(color = palette.border)
                Spacer(Modifier.height(12.dp))
                Text(
                    "PiDay for Android",
                    color = palette.onBackground.copy(alpha = 0.4f),
                    style = MaterialTheme.typography.bodySmall
                )
                Spacer(Modifier.height(48.dp))
            }
        }
    }
}
