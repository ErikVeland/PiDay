package academy.glasscode.piday.features.freesearch

import academy.glasscode.piday.design.AppPalette
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FreeSearchSheet(
    palette: AppPalette,
    onDismiss: () -> Unit,
    vm: FreeSearchViewModel = viewModel()
) {
    var query      by remember { mutableStateOf("") }
    val result     by vm.result.collectAsStateWithLifecycle()
    val isSearching by vm.isSearching.collectAsStateWithLifecycle()
    val error      by vm.error.collectAsStateWithLifecycle()
    val easterEgg = academy.glasscode.piday.core.domain.PiDelightCopy.freeSearchReaction(query)

    DisposableEffect(Unit) { onDispose { vm.clear() } }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(24.dp).imePadding()) {
            Text("Search Pi Digits",
                 style = MaterialTheme.typography.titleLarge,
                 color = palette.onBackground)
            Spacer(Modifier.height(16.dp))

            OutlinedTextField(
                value         = query,
                onValueChange = { new ->
                    query = new.filter { it.isDigit() }
                    vm.onQueryChange(query)
                },
                label         = { Text("Enter any digit sequence") },
                placeholder   = { Text("e.g. 314159") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine    = true,
                modifier      = Modifier.fillMaxWidth(),
                colors        = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = palette.accent,
                    focusedLabelColor    = palette.accent
                )
            )

            Spacer(Modifier.height(20.dp))

            when {
                isSearching -> CircularProgressIndicator(color = palette.accent)
                error != null -> Text(error!!, color = MaterialTheme.colorScheme.error)
                result != null -> {
                    val (position, excerpt) = result!!
                    Text("Found at position $position",
                         color = palette.accent,
                         style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    // Show a 50-char window of the excerpt centred on the match
                    val mid   = excerpt.length / 2
                    val from  = (mid - 25).coerceAtLeast(0)
                    val to    = (mid + 25 + query.length).coerceAtMost(excerpt.length)
                    Text(
                        "…${excerpt.substring(from, to)}…",
                        color      = palette.onBackground,
                        fontFamily = FontFamily.Monospace
                    )
                    easterEgg?.let {
                        Spacer(Modifier.height(8.dp))
                        Text(it, color = palette.accent, style = MaterialTheme.typography.bodySmall)
                    }
                }
                query.length >= 2 -> Text(
                    buildString {
                        append("Not found in first 5 billion digits")
                        easterEgg?.let { append("\n$it") }
                    },
                    color = palette.onBackground.copy(alpha = 0.5f)
                )
            }

            Spacer(Modifier.height(40.dp))
        }
    }
}
