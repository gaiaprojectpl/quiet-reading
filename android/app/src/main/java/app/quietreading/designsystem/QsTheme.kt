package app.quietreading.designsystem

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily

val LocalThemeId = staticCompositionLocalOf { ThemeId.PeachSage }

/** Read tokens as `QsTheme.colors.ink`, `QsTheme.shapes.btn` – same names as the Figma code syntax. */
object QsTheme {
    val id: ThemeId
        @Composable @ReadOnlyComposable get() = LocalThemeId.current
    val colors: QsColors
        @Composable @ReadOnlyComposable get() = LocalThemeId.current.colors()
    val shapes: QsShapes
        @Composable @ReadOnlyComposable get() = LocalThemeId.current.shapes()
    /** Serif heading family. System serif until the theme fonts are bundled. */
    val headFamily: FontFamily get() = FontFamily.Serif
}

/** Android 14+: Settings › Accessibility › Contrast. */
private fun Context.prefersHighContrast(): Boolean =
    Build.VERSION.SDK_INT >= 34 &&
        (getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).contrast >= 0.5f

/**
 * Resolves the theme: system dark → Night, high contrast → High contrast, otherwise the reader's choice.
 * Also maps the palette onto Material 3 so stock components look right.
 */
@Composable
fun QuietReadingTheme(chosen: ThemeId, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val resolved = when {
        context.prefersHighContrast() -> ThemeId.HighContrast
        isSystemInDarkTheme() -> ThemeId.Night
        else -> chosen
    }
    val c = resolved.colors()
    val scheme = if (resolved == ThemeId.Night) {
        darkColorScheme(
            primary = c.accent, onPrimary = c.onAccent, primaryContainer = c.soft2, onPrimaryContainer = c.accentInk,
            secondaryContainer = c.soft, onSecondaryContainer = c.accentInk,
            background = c.bg, onBackground = c.ink, surface = c.bg, onSurface = c.ink,
            surfaceContainer = c.surface, onSurfaceVariant = c.ink2, outline = c.lineStrong, outlineVariant = c.line,
            error = c.error, onError = c.onAccent, errorContainer = c.errorSoft,
        )
    } else {
        lightColorScheme(
            primary = c.accent, onPrimary = c.onAccent, primaryContainer = c.soft2, onPrimaryContainer = c.accentInk,
            secondaryContainer = c.soft, onSecondaryContainer = c.accentInk,
            background = c.bg, onBackground = c.ink, surface = c.bg, onSurface = c.ink,
            surfaceContainer = c.surface, onSurfaceVariant = c.ink2, outline = c.lineStrong, outlineVariant = c.line,
            error = c.error, onError = c.onAccent, errorContainer = c.errorSoft,
        )
    }
    CompositionLocalProvider(LocalThemeId provides resolved) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
