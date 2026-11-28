package app.quietreading.data

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf

/** Everything screens share: the books, settings and covers. Provided once in MainActivity. */
class AppEnvironment(context: Context) {
    val library = Library(context.applicationContext)
    val prefs = Prefs(context.applicationContext)
    val covers get() = library.covers
}

val LocalApp = staticCompositionLocalOf<AppEnvironment> { error("AppEnvironment not provided") }
