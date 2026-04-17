package academy.glasscode.piday.features.main

import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.design.LocalAppPalette
import academy.glasscode.piday.core.domain.CalendarFeaturedNumber
import academy.glasscode.piday.features.battle.DateBattleSheet
import academy.glasscode.piday.features.calendar.CalendarSheet
import academy.glasscode.piday.features.canvas.PiCanvasView
import academy.glasscode.piday.features.detail.DetailSheet
import academy.glasscode.piday.features.preferences.PreferencesScreen
import academy.glasscode.piday.features.saveddates.SavedDatesSheet
import academy.glasscode.piday.features.share.ShareSheet
import academy.glasscode.piday.features.stats.StatsSheet
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun MainScreen(
    vm: AppViewModel = viewModel(),
    onThemeChange: (AppThemeOption) -> Unit = {}
) {
    val palette        = LocalAppPalette.current
    val selectedDate   by vm.selectedDate.collectAsStateWithLifecycle()
    val lookupSummary  by vm.lookupSummary.collectAsStateWithLifecycle()
    val isLoading      by vm.isLoading.collectAsStateWithLifecycle()
    val featured       by vm.featuredNumber.collectAsStateWithLifecycle()

    var showCalendar    by remember { mutableStateOf(false) }
    var showDetail      by remember { mutableStateOf(false) }
    var showPreferences by remember { mutableStateOf(false) }
    var showSavedDates  by remember { mutableStateOf(false) }
    var showStats       by remember { mutableStateOf(false) }
    var showBattle      by remember { mutableStateOf(false) }
    var showShare       by remember { mutableStateOf(false) }
    var showFeaturedMenu by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .systemBarsPadding()
    ) {
        // Pi digit canvas — fills the whole screen
        PiCanvasView(
            excerpt    = lookupSummary?.bestMatch?.excerpt,
            bestMatch  = lookupSummary?.bestMatch,
            palette    = palette,
            modifier   = Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription = "Digit canvas. Swipe left or right to change date."
                },
            onSwipeLeft  = { vm.nextDay() },
            onSwipeRight = { vm.previousDay() },
            onSwipeUp    = { showDetail = true }
        )

        // Loading indicator
        if (isLoading) {
            CircularProgressIndicator(
                color    = palette.accent,
                modifier = Modifier.align(Alignment.Center)
            )
        }

        // Wordmark / featured-number picker — centred at top
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 16.dp)
        ) {
            Text(
                text = featured.logoSymbol,
                fontSize = 28.sp,
                color = palette.accent.copy(alpha = 0.7f),
                modifier = Modifier.clickable { showFeaturedMenu = true }
            )
            DropdownMenu(
                expanded = showFeaturedMenu,
                onDismissRequest = { showFeaturedMenu = false }
            ) {
                CalendarFeaturedNumber.entries.forEach { item ->
                    DropdownMenuItem(
                        text = { Text("${item.logoSymbol}  ${item.title}") },
                        onClick = {
                            showFeaturedMenu = false
                            vm.setFeaturedNumber(item)
                        }
                    )
                }
            }
        }

        // Bottom control bar
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 32.dp, vertical = 24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment     = Alignment.CenterVertically
        ) {
            IconButton(onClick = { showCalendar = true }) {
                Icon(
                    Icons.Default.CalendarMonth,
                    contentDescription = "Open calendar heat map",
                    tint               = palette.accent
                )
            }

            IconButton(onClick = { showStats = true }) {
                Icon(
                    Icons.Default.BarChart,
                    contentDescription = "Open stats",
                    tint = palette.accent
                )
            }

            // Date display
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                lookupSummary?.bestMatch?.let { best ->
                    Text(
                        text     = "Position ${vm.indexingConvention.displayPosition(best.storedPosition)}",
                        color    = palette.accent,
                        fontSize = 13.sp
                    )
                } ?: run {
                    if (!isLoading) {
                        Text("Not found", color = palette.onBackground.copy(alpha = 0.4f), fontSize = 13.sp)
                    }
                }
            }

            IconButton(onClick = { showDetail = true }) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = "Open detail view",
                    tint               = palette.accent
                )
            }
        }
    }

    // Sheets
    if (showCalendar) {
        CalendarSheet(vm = vm, palette = palette, onDismiss = { showCalendar = false })
    }

    if (showDetail) {
        DetailSheet(
            vm                = vm,
            palette           = palette,
            onDismiss         = { showDetail = false },
            onOpenPreferences = { showDetail = false; showPreferences = true },
            onOpenSavedDates  = { showDetail = false; showSavedDates = true },
            onOpenBattle      = { showDetail = false; showBattle = true },
            onOpenShare       = { showDetail = false; showShare = true }
        )
    }

    if (showPreferences) {
        PreferencesScreen(
            vm            = vm,
            palette       = palette,
            onDismiss     = { showPreferences = false },
            onThemeChange = { theme ->
                showPreferences = false
                onThemeChange(theme)
            }
        )
    }

    if (showSavedDates) {
        SavedDatesSheet(
            vm            = vm,
            palette       = palette,
            onDismiss     = { showSavedDates = false },
            onDateSelected = { date ->
                vm.selectDate(date)
                showSavedDates = false
            }
        )
    }

    if (showStats) {
        StatsSheet(vm = vm, palette = palette, onDismiss = { showStats = false })
    }

    if (showBattle) {
        DateBattleSheet(
            vm = vm,
            palette = palette,
            anchorDate = selectedDate,
            onDismiss = { showBattle = false }
        )
    }

    if (showShare) {
        ShareSheet(vm = vm, palette = palette, onDismiss = { showShare = false })
    }
}
