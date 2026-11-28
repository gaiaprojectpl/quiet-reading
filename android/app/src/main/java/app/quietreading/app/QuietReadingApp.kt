package app.quietreading.app

import android.content.res.Configuration
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.navigation.compose.NavHost
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.current
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QuietReadingTheme
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.components.AppTab
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NotificationHost
import app.quietreading.designsystem.components.Notifier
import app.quietreading.designsystem.components.QsTabBar
import app.quietreading.designsystem.components.QsTabRail
import app.quietreading.feature.add.AddSheet
import app.quietreading.feature.add.addGraph
import app.quietreading.feature.book.bookGraph
import app.quietreading.feature.home.homeGraph
import app.quietreading.feature.quotes.quotesGraph
import app.quietreading.feature.library.libraryGraph
import app.quietreading.feature.onboarding.OnboardingFlow
import app.quietreading.feature.onboarding.onboardingGraph
import app.quietreading.feature.settings.settingsGraph
import app.quietreading.feature.stats.statsGraph

/** Resolves the theme, shows Flow 1 on first launch, then the one navigation used everywhere. */
@Composable
fun QuietReadingApp(link: String? = null, onLinkHandled: () -> Unit = {}) {
    val app = LocalApp.current
    val (themeRaw, _) = rememberPref(Keys.theme, ThemeId.PeachSage.name)
    val (forceHC, _) = rememberPref(Keys.forceHighContrast, false)
    val (plus, _) = rememberPref(Keys.plusUnlocked, false)
    val (_, setOnboardingDone) = rememberPref(Keys.onboardingDone, true)
    // Read the real value once before deciding, so nothing flashes.
    var loaded by remember { mutableStateOf(false) }
    var firstRun by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        firstRun = !app.prefs.get(Keys.onboardingDone, false)
        loaded = true
    }
    val chosen = ThemeId.entries.firstOrNull { it.name == themeRaw || it.name.equals(themeRaw, true) } ?: ThemeId.PeachSage
    val notifier = remember { Notifier() }

    QuietReadingTheme(chosen, forceHighContrast = forceHC, isPlus = plus) {
        CompositionLocalProvider(LocalNotifier provides notifier) {
            NotificationHost(notifier) {
                Box(Modifier.fillMaxSize().background(QsTheme.colors.bg)) {
                    if (loaded) {
                        if (firstRun) {
                            OnboardingFlow(onFinish = { setOnboardingDone(true); firstRun = false })
                        } else {
                            MainTabs(link, onLinkHandled)
                        }
                    }
                }
            }
        }
    }
    // Covers fill in by themselves: at launch and whenever books arrive (import, add).
    LaunchedEffect(Unit) {
        app.library.books.map { b -> b.count() }.distinctUntilChanged().collectLatest {
            app.covers.backfill(app.library, app.library.books.first())
        }
    }
}

@Composable
private fun MainTabs(link: String?, onLinkHandled: () -> Unit) {
    val controller = rememberNavController()
    var showAdd by rememberSaveable { mutableStateOf(false) }
    val nav = remember(controller) { AppNav(controller) { showAdd = true } }
    val entry by controller.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val tab = when (route) {
        Routes.LIBRARY -> AppTab.Library
        Routes.STATS -> AppTab.Stats
        Routes.SETTINGS -> AppTab.Settings
        else -> AppTab.Home
    }
    val showNav = route == null || route in Routes.tabs
    val wide = LocalConfiguration.current.screenWidthDp >= 600 || LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE && LocalConfiguration.current.screenHeightDp >= 480
    val select: (AppTab) -> Unit = { t ->
        nav.openTab(when (t) { AppTab.Library -> Routes.LIBRARY; AppTab.Stats -> Routes.STATS; AppTab.Settings -> Routes.SETTINGS; else -> Routes.HOME })
    }
    val fade = if (QsTheme.reduceMotion) 0 else QsMotion.base

    val host: @Composable (Modifier) -> Unit = { m ->
        NavHost(
            controller, startDestination = Routes.HOME, modifier = m,
            enterTransition = { fadeIn(tween(fade)) }, exitTransition = { fadeOut(tween(fade)) },
        ) {
            homeGraph(nav)
            libraryGraph(nav)
            addGraph(nav)
            statsGraph(nav)
            settingsGraph(nav)
            onboardingGraph(nav)
            bookGraph(nav)
            quotesGraph(nav)
        }
    }

    val app = LocalApp.current
    LaunchedEffect(link) {
        val url = link ?: return@LaunchedEffect
        onLinkHandled()
        val current = app.library.books.first().current
        DeepLinks.open(url, nav, current?.id)
    }

    if (wide && showNav) {
        Row(Modifier.fillMaxSize()) {
            QsTabRail(tab, select, onAdd = { showAdd = true })
            host(Modifier.weight(1f))
        }
    } else {
        Column(Modifier.fillMaxSize()) {
            host(Modifier.weight(1f))
            if (showNav) QsTabBar(tab, select, onAdd = { showAdd = true })
        }
    }
    if (showAdd) AddSheet(nav, onDismiss = { showAdd = false })
}
