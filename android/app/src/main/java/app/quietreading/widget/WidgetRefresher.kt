package app.quietreading.widget

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import app.quietreading.data.LocalApp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Keeps the widgets in step with the app: books, quotes, goal, theme, Plus,
 * and the system's dark mode (the widget is redrawn when the app sees the change).
 */
@Composable
fun WidgetRefresher() {
    val app = LocalApp.current
    val context = LocalContext.current
    val uiMode = LocalConfiguration.current.uiMode
    LaunchedEffect(uiMode) {
        combine(app.library.books, app.prefs.data) { books, prefs ->
            val latest = books.maxOfOrNull { it.lastUpdated } ?: 0
            val pages = books.sumOf { it.currentPage }
            val covers = books.count { it.coverFile != null }
            val quotes = books.sumOf { b -> b.quotes.size + b.quotes.count { it.showOnWidget } * 1000 }
            "${books.size}-$latest-$pages-$covers-$quotes-${prefs.asMap().hashCode()}"
        }.distinctUntilChanged().collectLatest {
            delay(300) // let quick changes settle
            Widgets.refresh(context)
        }
    }
}
