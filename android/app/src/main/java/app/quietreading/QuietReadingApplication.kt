package app.quietreading

import android.app.Application
import app.quietreading.data.AppEnvironment

class QuietReadingApplication : Application() {
    val env by lazy { AppEnvironment(this) }
}
