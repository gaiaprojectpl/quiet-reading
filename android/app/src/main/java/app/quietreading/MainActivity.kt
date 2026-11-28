package app.quietreading

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import app.quietreading.app.QuietReadingApp
import app.quietreading.data.LocalApp

class MainActivity : ComponentActivity() {
    /** A quietreading:// link waiting to be opened (reminder, recap, widget). */
    private val link = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) link.value = intent?.dataString
        val env = (application as QuietReadingApplication).env
        setContent {
            CompositionLocalProvider(LocalApp provides env) {
                QuietReadingApp(link = link.value, onLinkHandled = { link.value = null })
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { link.value = it }
    }
}
