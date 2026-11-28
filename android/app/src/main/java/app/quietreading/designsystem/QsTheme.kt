package app.quietreading.designsystem

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import app.quietreading.R

val LocalThemeId = staticCompositionLocalOf { ThemeId.PeachSage }

/** Reduce Motion: system "Remove animations" (animator duration scale 0). Movement becomes a fade or nothing. */
val LocalReduceMotion = compositionLocalOf { false }

/** Read tokens as `QsTheme.colors.ink`, `QsTheme.shapes.btn` – same names as the Figma code syntax. */
object QsTheme {
    val id: ThemeId
        @Composable @ReadOnlyComposable get() = LocalThemeId.current
    val colors: QsColors
        @Composable @ReadOnlyComposable get() = LocalThemeId.current.colors()
    val shapes: QsShapes
        @Composable @ReadOnlyComposable get() = LocalThemeId.current.shapes()
    /** Serif heading family of the active theme (bundled variable fonts, OFL). */
    val headFamily: FontFamily
        @Composable @ReadOnlyComposable get() = LocalThemeId.current.headFamily()
    val reduceMotion: Boolean
        @Composable @ReadOnlyComposable get() = LocalReduceMotion.current

    /** Heading in the theme serif, e.g. `QsTheme.headline(34)` for screen titles. Scales with font size. */
    @Composable @ReadOnlyComposable
    fun headline(size: Int): TextStyle {
        val t = LocalThemeId.current
        return TextStyle(fontFamily = t.headFamily(), fontWeight = t.headFont().weight, fontSize = size.sp, lineHeight = (size * 1.2).sp)
    }
}

/**
 * Body text uses the system font (Roboto) in sp so it follows the reader's font size.
 * Names match the iOS text styles used in the same places.
 */
object QsType {
    val body = TextStyle(fontSize = 16.sp, lineHeight = 22.sp)
    val subheadline = TextStyle(fontSize = 14.sp, lineHeight = 20.sp)
    val footnote = TextStyle(fontSize = 13.sp, lineHeight = 18.sp)
    val caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp)
    val caption2 = TextStyle(fontSize = 11.sp, lineHeight = 14.sp)
    val title3 = TextStyle(fontSize = 20.sp, lineHeight = 26.sp)
}

fun TextStyle.semibold() = copy(fontWeight = FontWeight.SemiBold)
fun TextStyle.medium() = copy(fontWeight = FontWeight.Medium)
fun TextStyle.size(s: TextUnit) = copy(fontSize = s)

@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
private fun variable(res: Int, weight: FontWeight) =
    Font(res, weight, variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)))

private fun family(res: Int) = FontFamily(
    variable(res, FontWeight.Normal), variable(res, FontWeight.Medium),
    variable(res, FontWeight.SemiBold), variable(res, FontWeight.Bold),
)

private val newsreader = family(R.font.newsreader)
private val fraunces = family(R.font.fraunces)
private val lora = family(R.font.lora)
private val playfair = family(R.font.playfair_display)

fun ThemeId.headFamily(): FontFamily = when (headFont().family) {
    "Fraunces" -> fraunces
    "Lora" -> lora
    "Playfair Display" -> playfair
    else -> newsreader
}

/** Android 14+: Settings › Accessibility › Contrast. */
private fun Context.prefersHighContrast(): Boolean =
    Build.VERSION.SDK_INT >= 34 &&
        (getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).contrast >= 0.5f

private fun Context.reduceMotion(): Boolean =
    Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

/**
 * Resolves the theme: high contrast (system or the in-app switch) > system dark (Night) > the reader's choice.
 * A Plus theme without Plus falls back to Peach & Sage. Also maps the palette onto Material 3.
 */
@Composable
fun QuietReadingTheme(chosen: ThemeId, forceHighContrast: Boolean = false, isPlus: Boolean = true, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val resolved = when {
        forceHighContrast || context.prefersHighContrast() -> ThemeId.HighContrast
        isSystemInDarkTheme() -> ThemeId.Night
        chosen.requiresPlus && !isPlus -> ThemeId.PeachSage
        else -> chosen
    }
    val c = resolved.colors()
    val scheme = if (resolved == ThemeId.Night) {
        darkColorScheme(
            primary = c.accent, onPrimary = c.onAccent, primaryContainer = c.soft2, onPrimaryContainer = c.accentInk,
            secondaryContainer = c.soft, onSecondaryContainer = c.accentInk,
            background = c.bg, onBackground = c.ink, surface = c.bg, onSurface = c.ink,
            surfaceContainer = c.surface, surfaceContainerLow = c.surface, surfaceContainerHigh = c.surface,
            onSurfaceVariant = c.ink2, outline = c.lineStrong, outlineVariant = c.line,
            error = c.error, onError = c.onAccent, errorContainer = c.errorSoft,
            inverseSurface = c.inverse, inverseOnSurface = c.onInverse, scrim = c.scrim,
        )
    } else {
        lightColorScheme(
            primary = c.accent, onPrimary = c.onAccent, primaryContainer = c.soft2, onPrimaryContainer = c.accentInk,
            secondaryContainer = c.soft, onSecondaryContainer = c.accentInk,
            background = c.bg, onBackground = c.ink, surface = c.bg, onSurface = c.ink,
            surfaceContainer = c.surface, surfaceContainerLow = c.surface, surfaceContainerHigh = c.surface,
            onSurfaceVariant = c.ink2, outline = c.lineStrong, outlineVariant = c.line,
            error = c.error, onError = c.onAccent, errorContainer = c.errorSoft,
            inverseSurface = c.inverse, inverseOnSurface = c.onInverse, scrim = c.scrim,
        )
    }
    CompositionLocalProvider(LocalThemeId provides resolved, LocalReduceMotion provides context.reduceMotion()) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
