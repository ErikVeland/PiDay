package academy.glasscode.piday.features.main

import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.design.LocalAppPalette
import academy.glasscode.piday.features.calendar.CalendarSheet
import academy.glasscode.piday.features.canvas.PiCanvasView
import academy.glasscode.piday.features.detail.DetailSheet
import academy.glasscode.piday.features.freesearch.FreeSearchSheet
import academy.glasscode.piday.features.preferences.PreferencesScreen
import academy.glasscode.piday.features.saveddates.SavedDatesSheet
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
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

    var showCalendar    by remember { mutableStateOf(false) }
    var showDetail      by remember { mutableStateOf(false) }
    var showPreferences by remember { mutableStateOf(false) }
    var showFreeSearch  by remember { mutableStateOf(false) }
    var showSavedDates  by remember { mutableStateOf(false) }

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
                    contentDescription = "Pi digit canvas. Swipe left or right to change date."
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

        // Wordmark — centred at top
        Text(
            text     = "π",
            fontSize = 28.sp,
            color    = palette.accent.copy(alpha = 0.7f),
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 16.dp)
        )

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
            onOpenFreeSearch  = { showDetail = false; showFreeSearch = true },
            onOpenSavedDates  = { showDetail = false; showSavedDates = true }
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

    if (showFreeSearch) {
        FreeSearchSheet(palette = palette, onDismiss = { showFreeSearch = false })
    }

    if (showSavedDates) {
        SavedDatesSheet(
            palette       = palette,
            onDismiss     = { showSavedDates = false },
            onDateSelected = { date ->
                vm.selectDate(date)
                showSavedDates = false
            }
        )
    }
}
