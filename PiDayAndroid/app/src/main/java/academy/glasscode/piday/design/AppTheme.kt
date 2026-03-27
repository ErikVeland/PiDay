package academy.glasscode.piday.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

enum class AppThemeOption { SLATE, FROST, COPPICE, EMBER, AURORA, CUSTOM }

// AppPalette carries all semantic color tokens the app needs.
// It maps to iOS ThemePalette — views use these tokens, never raw Colors.
data class AppPalette(
    val background: Color,
    val surface: Color,
    val onBackground: Color,
    val accent: Color,
    val border: Color,
    val dayColor: Color,
    val monthColor: Color,
    val yearColor: Color,
    val heatNone: Color,
    val heatFaint: Color,
    val heatCool: Color,
    val heatWarm: Color,
    val heatHot: Color,
    val isDark: Boolean
)

object PiThemes {
    val slate = AppPalette(
        background   = Color(0xFF1C1C1E),
        surface      = Color(0xFF2C2C2E),
        onBackground = Color(0xFFEEEEEE),
        accent       = Color(0xFF5E9CEA),
        border       = Color(0xFF3A3A3C),
        dayColor     = Color(0xFFFF9500),
        monthColor   = Color(0xFF32D74B),
        yearColor    = Color(0xFF5E9CEA),
        heatNone     = Color(0xFF2C2C2E),
        heatFaint    = Color(0xFF2A3A4A),
        heatCool     = Color(0xFF1E4A7A),
        heatWarm     = Color(0xFF2460A0),
        heatHot      = Color(0xFF4F8EDB),
        isDark       = true
    )

    val frost = AppPalette(
        background   = Color(0xFFF5F5F7),
        surface      = Color(0xFFFFFFFF),
        onBackground = Color(0xFF1C1C1E),
        accent       = Color(0xFF007AFF),
        border       = Color(0xFFD1D1D6),
        dayColor     = Color(0xFFFF6B00),
        monthColor   = Color(0xFF00A550),
        yearColor    = Color(0xFF007AFF),
        heatNone     = Color(0xFFE5E5EA),
        heatFaint    = Color(0xFFD0E4F7),
        heatCool     = Color(0xFF90C4F0),
        heatWarm     = Color(0xFF4A9EE8),
        heatHot      = Color(0xFF007AFF),
        isDark       = false
    )

    val coppice = AppPalette(
        background   = Color(0xFF0E1A12),
        surface      = Color(0xFF1A2E1F),
        onBackground = Color(0xFFE8F5E9),
        accent       = Color(0xFF4CAF50),
        border       = Color(0xFF2D4A32),
        dayColor     = Color(0xFFFF9800),
        monthColor   = Color(0xFF4CAF50),
        yearColor    = Color(0xFF80CBC4),
        heatNone     = Color(0xFF1A2E1F),
        heatFaint    = Color(0xFF1B3A22),
        heatCool     = Color(0xFF1B4D28),
        heatWarm     = Color(0xFF2E7D32),
        heatHot      = Color(0xFF43A047),
        isDark       = true
    )

    val ember = AppPalette(
        background   = Color(0xFFFFF8F0),
        surface      = Color(0xFFFFFFFF),
        onBackground = Color(0xFF2D1B00),
        accent       = Color(0xFFE65100),
        border       = Color(0xFFFFCC80),
        dayColor     = Color(0xFFE65100),
        monthColor   = Color(0xFF6D4C41),
        yearColor    = Color(0xFFBF360C),
        heatNone     = Color(0xFFFFF3E0),
        heatFaint    = Color(0xFFFFE0B2),
        heatCool     = Color(0xFFFFCC80),
        heatWarm     = Color(0xFFFFB74D),
        heatHot      = Color(0xFFFF9800),
        isDark       = false
    )

    fun forOption(option: AppThemeOption): AppPalette = when (option) {
        AppThemeOption.SLATE   -> slate
        AppThemeOption.FROST   -> frost
        AppThemeOption.COPPICE -> coppice
        AppThemeOption.EMBER   -> ember
        AppThemeOption.AURORA  -> slate  // TODO: add aurora palette
        AppThemeOption.CUSTOM  -> slate  // TODO: custom accent color
    }
}

val LocalAppPalette = staticCompositionLocalOf { PiThemes.slate }

@Composable
fun PiDayTheme(
    palette: AppPalette = PiThemes.slate,
    content: @Composable () -> Unit
) {
    val colorScheme = if (palette.isDark) {
        darkColorScheme(
            background = palette.background,
            surface    = palette.surface,
            primary    = palette.accent,
            onBackground = palette.onBackground,
            onSurface  = palette.onBackground,
        )
    } else {
        lightColorScheme(
            background = palette.background,
            surface    = palette.surface,
            primary    = palette.accent,
            onBackground = palette.onBackground,
            onSurface  = palette.onBackground,
        )
    }

    CompositionLocalProvider(LocalAppPalette provides palette) {
        MaterialTheme(colorScheme = colorScheme, content = content)
    }
}
