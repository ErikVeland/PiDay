package academy.glasscode.piday.features.share

import academy.glasscode.piday.core.domain.ShareCardStyle
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Share Result", style = MaterialTheme.typography.titleLarge, color = palette.onBackground)
            Spacer(Modifier.height(8.dp))
            Text(
                "Pick a vibe: a clean classic result or the nerdier stats-heavy version.",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.onBackground.copy(alpha = 0.7f)
            )
            Spacer(Modifier.height(20.dp))

            ShareCardOption(
                title = "Classic",
                body = vm.shareText(ShareCardStyle.CLASSIC),
                palette = palette,
                onShare = { shareText(context, "PiDay Result", vm.shareText(ShareCardStyle.CLASSIC)) }
            )

            Spacer(Modifier.height(12.dp))

            ShareCardOption(
                title = "Nerd",
                body = vm.shareText(ShareCardStyle.NERD),
                palette = palette,
                onShare = { shareText(context, "PiDay Nerd Stats", vm.shareText(ShareCardStyle.NERD)) }
            )

            Spacer(Modifier.height(28.dp))
        }
    }
}

@Composable
private fun ShareCardOption(
    title: String,
    body: String,
    palette: AppPalette,
    onShare: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = palette.accent)
        Text(body, style = MaterialTheme.typography.bodyMedium, color = palette.onBackground)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = onShare) {
                Text("Share")
            }
            OutlinedButton(onClick = onShare) {
                Text("Copy via Share Sheet")
            }
        }
    }
}

private fun shareText(context: Context, title: String, body: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, title)
        putExtra(Intent.EXTRA_TEXT, body)
    }
    context.startActivity(Intent.createChooser(intent, title))
}
