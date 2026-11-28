package app.quietreading

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import app.quietreading.app.QuietReadingApp
import app.quietreading.app.SplashView
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.LocalReduceMotion
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSpace
import app.quietreading.feature.plus.PlusAccess
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    /** A quietreading:// link waiting to be opened (reminder, recap, widget). */
    private val link = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val coldStart = savedInstanceState == null
        if (coldStart) link.value = intent?.dataString
        lifecycleScope.launch { PlusAccess.applyDebugExtras(this@MainActivity, intent?.extras) }
        val env = (application as QuietReadingApplication).env
        setContent {
            CompositionLocalProvider(LocalApp provides env) {
                // Flow 11: the splash plays once per launch from zero, then the app rises 12 dp and fades in.
                var splashDone by rememberSaveable { mutableStateOf(!coldStart) }
                val reveal = remember { Animatable(if (coldStart) 0f else 1f) }
                val reduce = LocalReduceMotion.current
                val rise = with(LocalDensity.current) { QsSpace.s12.toPx() }
                LaunchedEffect(splashDone) { if (splashDone) reveal.animateTo(1f, tween(QsMotion.slow, easing = FastOutSlowInEasing)) }
                Box(Modifier.fillMaxSize()) {
                    Box(Modifier.fillMaxSize().graphicsLayer {
                        alpha = reveal.value
                        translationY = if (reduce) 0f else rise * (1 - reveal.value)
                    }) {
                        QuietReadingApp(link = link.value, onLinkHandled = { link.value = null })
                    }
                    if (!splashDone) SplashView(onFinished = { splashDone = true })
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { link.value = it }
        lifecycleScope.launch { PlusAccess.applyDebugExtras(this@MainActivity, intent.extras) }
    }
}
