package academy.glasscode.piday

import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.design.PiDayTheme
import academy.glasscode.piday.design.PiThemes
import academy.glasscode.piday.features.main.MainScreen
import academy.glasscode.piday.services.PreferencesStore
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val prefsStore = remember { PreferencesStore(applicationContext) }
            val activeTheme by prefsStore.themeFlow.collectAsState(initial = AppThemeOption.SLATE)
            val palette = PiThemes.forOption(activeTheme)

            PiDayTheme(palette = palette) {
                MainScreen(onThemeChange = { })
            }
        }
    }
}
