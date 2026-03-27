package academy.glasscode.piday

import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.design.PiDayTheme
import academy.glasscode.piday.design.PiThemes
import academy.glasscode.piday.features.main.MainScreen
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            var activeTheme by remember { mutableStateOf(AppThemeOption.SLATE) }
            val palette = PiThemes.forOption(activeTheme)

            PiDayTheme(palette = palette) {
                MainScreen(onThemeChange = { activeTheme = it })
            }
        }
    }
}
