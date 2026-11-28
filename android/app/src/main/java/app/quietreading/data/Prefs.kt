package app.quietreading.data

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private val Context.store by preferencesDataStore("quiet_reading")

/** Settings and profile, kept on this phone. Same key names as iOS (UserDefaults). */
object Keys {
    val theme = stringPreferencesKey("themeID")
    val forceHighContrast = booleanPreferencesKey("forceHighContrast")
    val onboardingDone = booleanPreferencesKey("onboardingDone")
    val name = stringPreferencesKey("profileName")
    val handle = stringPreferencesKey("profileHandle")
    val about = stringPreferencesKey("profileAbout")
    val showOnWidgets = booleanPreferencesKey("profileShowOnWidgets")
    val goal = intPreferencesKey("readingGoal")
    val reminderOn = booleanPreferencesKey("reminderOn")
    /** Minutes after midnight. */
    val reminderMinutes = intPreferencesKey("reminderMinutes")
    val appIcon = stringPreferencesKey("appIcon")
    val lastImport = longPreferencesKey("lastImportDate")
    val lastImportSource = stringPreferencesKey("lastImportSource")
    val monthlyRecap = booleanPreferencesKey("monthlyRecap")
    val plusUnlocked = booleanPreferencesKey("plusUnlocked")
    val noteInputMode = stringPreferencesKey("noteInputMode")
    val companionEnabled = booleanPreferencesKey("companionEnabled")
}

class Prefs(private val context: Context) {
    val data: Flow<Preferences> = context.store.data

    fun <T> flow(key: Preferences.Key<T>, default: T): Flow<T> = data.map { it[key] ?: default }
    suspend fun <T> get(key: Preferences.Key<T>, default: T): T = flow(key, default).first()
    suspend fun <T> set(key: Preferences.Key<T>, value: T?) {
        context.store.edit { if (value == null) it.remove(key) else it[key] = value }
    }
}

/** A setting as Compose state: `val (goal, setGoal) = rememberPref(Keys.goal, 0)`. */
@Composable
fun <T> rememberPref(key: Preferences.Key<T>, default: T): Pair<T, (T?) -> Unit> {
    val prefs = LocalApp.current.prefs
    val scope = rememberCoroutineScope()
    val flow = remember(key) { prefs.flow(key, default) }
    val value = flow.collectAsState(initial = default).value
    return value to { v: T? -> scope.launch { prefs.set(key, v) } }
}
