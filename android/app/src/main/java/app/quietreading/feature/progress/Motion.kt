package app.quietreading.feature.progress

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import kotlinx.coroutines.delay

/** Content that softly rises into place when it first appears (just a fade with Reduce Motion). */
@Composable
fun Modifier.gentleAppear(delay: Int = 0): Modifier {
    val reduce = QsTheme.reduceMotion
    val p = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        if (!reduce) delay(delay.toLong())
        p.animateTo(1f, tween(if (reduce) QsMotion.fast else QsMotion.slow))
    }
    val rise = QsSpace.s12
    return graphicsLayer {
        alpha = p.value
        translationY = if (reduce) 0f else (1f - p.value) * rise.toPx()
    }
}

