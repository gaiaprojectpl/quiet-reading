package app.quietreading

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QuietReadingTheme
import app.quietreading.designsystem.ThemeId
import app.quietreading.feature.AddBookScreen
import app.quietreading.feature.HomeScreen
import app.quietreading.feature.LibraryScreen
import app.quietreading.feature.SettingsScreen
import app.quietreading.feature.StatsScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { QuietReadingApp() }
    }
}

enum class AppTab(val label: String, @param:DrawableRes val icon: Int) {
    Home("Home", R.drawable.ic_qs_home),
    Library("Library", R.drawable.ic_qs_library),
    Add("Add", R.drawable.ic_qs_plus),
    Stats("Stats", R.drawable.ic_qs_stats),
    Settings("Settings", R.drawable.ic_qs_settings),
}

private const val PREFS = "quiet_reading"
private const val KEY_THEME = "theme_id"

@Composable
fun QuietReadingApp() {
    val prefs = LocalContext.current.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    var chosen by remember {
        mutableStateOf(runCatching { ThemeId.valueOf(prefs.getString(KEY_THEME, null) ?: "") }.getOrDefault(ThemeId.PeachSage))
    }
    var tab by rememberSaveable { mutableStateOf(AppTab.Home) }

    QuietReadingTheme(chosen) {
        val c = QsTheme.colors
        Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = c.bg,
            bottomBar = {
                NavigationBar(containerColor = c.surface) {
                    AppTab.entries.forEach { t ->
                        NavigationBarItem(
                            selected = tab == t,
                            onClick = { tab = t },
                            icon = { Icon(painterResource(t.icon), contentDescription = null) },
                            label = { Text(t.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = c.accentInk, selectedTextColor = c.ink,
                                indicatorColor = c.soft,
                                unselectedIconColor = c.ink2, unselectedTextColor = c.ink2,
                            ),
                        )
                    }
                }
            },
        ) { padding ->
            val m = Modifier.padding(padding)
            androidx.compose.foundation.layout.Box(m) {
                when (tab) {
                    AppTab.Home -> HomeScreen()
                    AppTab.Library -> LibraryScreen()
                    AppTab.Add -> AddBookScreen()
                    AppTab.Stats -> StatsScreen()
                    AppTab.Settings -> SettingsScreen(chosen) {
                        chosen = it
                        prefs.edit().putString(KEY_THEME, it.name).apply()
                    }
                }
            }
        }
    }
}
