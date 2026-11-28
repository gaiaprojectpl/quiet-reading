package app.quietreading.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.TextStyle
import app.quietreading.R
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.colors
import app.quietreading.designsystem.headFamily
import app.quietreading.designsystem.headFont
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Flow 11 · Splash, shown when the app starts from zero. It takes over from the system launch screen
 * (sage, cream "q" with its ribbon tucked in), so there is no jump.
 * 0–400 ms the bookmark ribbon drops (gentle spring) · 400–750 ms "Quiet Reading" fades in and rises
 * while the q lifts · then sage fades into the app. Never waits for anything; any tap skips.
 * Reduce Motion: frame 1 cross-fades to the app in 200 ms. Brand colours are Peach & Sage on purpose.
 */
@Composable
fun SplashView(onFinished: () -> Unit) {
    val brand = ThemeId.PeachSage.colors()
    val reduce = QsTheme.reduceMotion
    val ribbon = remember { Animatable(0f) }
    val name = remember { Animatable(0f) }
    val alpha = remember { Animatable(1f) }
    val scope = rememberCoroutineScope()
    var finishing = remember { booleanArrayOf(false) }
    /** Same size as the system splash artwork (the middle 160 dp of the 240 dp icon). */
    val logo = 160.dp
    val density = LocalDensity.current

    fun finish(ms: Int = 350) {
        if (finishing[0]) return
        finishing[0] = true
        scope.launch {
            alpha.animateTo(0f, tween(ms, easing = FastOutSlowInEasing))
            onFinished()
        }
    }

    LaunchedEffect(Unit) {
        if (reduce) {
            delay(150); finish(200); return@LaunchedEffect
        }
        delay(120)
        ribbon.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessMediumLow))
        launch { name.animateTo(1f, tween(350, easing = FastOutSlowInEasing)) }
        delay(450)
        finish()
    }

    Box(
        Modifier.fillMaxSize()
            .graphicsLayer { this.alpha = alpha.value }
            .background(brand.accent)
            .clickable(remember { MutableInteractionSource() }, indication = null) { finish() }
            .clearAndSetSemantics { contentDescription = "Quiet Reading" },
        contentAlignment = Alignment.Center,
    ) {
        // The q lifts a little to make room for the name.
        Box(Modifier.size(logo).offset(y = -QsSpace.s24 * name.value)) {
            Icon(painterResource(R.drawable.ic_qs_logo_bowl), null, tint = brand.bg, modifier = Modifier.fillMaxSize())
            Canvas(Modifier.fillMaxSize()) {
                val s = size.width / 38.4f
                val left = 20.25f * s; val right = 24.3f * s; val top = 9.735f * s
                val shortEnd = 20.1075f * s; val fullEnd = 29.8575f * s
                val p = ribbon.value
                val bottom = shortEnd + (fullEnd - shortEnd) * p
                val notch = 2.25f * s * p.coerceIn(0f, 1f)
                drawPath(Path().apply {
                    moveTo(left, top); lineTo(right, top); lineTo(right, bottom)
                    lineTo((left + right) / 2, bottom - notch); lineTo(left, bottom); close()
                }, brand.bg)
            }
        }
        Text(
            "Quiet Reading",
            style = TextStyle(fontFamily = ThemeId.PeachSage.headFamily(), fontWeight = ThemeId.PeachSage.headFont().weight, fontSize = 30.sp),
            color = brand.bg,
            modifier = Modifier
                .offset(y = logo / 2 + QsSpace.s12 + QsSpace.s8 * (1 - name.value))
                .graphicsLayer { this.alpha = name.value },
        )
    }
}
