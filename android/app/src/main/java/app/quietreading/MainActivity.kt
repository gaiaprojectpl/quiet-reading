package app.quietreading

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import app.quietreading.app.QuietReadingApp
import app.quietreading.data.AppEnvironment
import app.quietreading.data.LocalApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val env = (application as QuietReadingApplication).env
        setContent {
            CompositionLocalProvider(LocalApp provides env) { QuietReadingApp() }
        }
    }
}
