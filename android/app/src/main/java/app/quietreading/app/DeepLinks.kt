package app.quietreading.app

import app.quietreading.feature.book.BookRoutes
import app.quietreading.feature.stats.StatsRoutes

/**
 * quietreading:// links (same as iOS): book/<id>, add, stats, update-current, finish-current, year.
 * Used by the daily reminder, the monthly recap and the widgets (update/<id> = the widget's +).
 */
object DeepLinks {
    fun open(url: String, nav: AppNav, currentBookId: Long?) {
        val path = url.removePrefix("quietreading://").trimEnd('/')
        val parts = path.split("/")
        when (parts.firstOrNull()) {
            "book" -> parts.getOrNull(1)?.toLongOrNull()?.let { nav.openBook(it) }
            "add" -> nav.showAddSheet()
            "stats" -> nav.openTab(Routes.STATS)
            "year" -> { nav.openTab(Routes.STATS); nav.controller.navigate(StatsRoutes.year()) }
            "update" -> parts.getOrNull(1)?.toLongOrNull()?.let { nav.openBook(it); nav.controller.navigate(BookRoutes.update(it)) }
            "plus" -> nav.controller.navigate("plus")
            "update-current" -> currentBookId?.let { nav.openBook(it); nav.controller.navigate(BookRoutes.update(it)) } ?: nav.showAddSheet()
            "finish-current" -> currentBookId?.let { nav.openBook(it); nav.controller.navigate(BookRoutes.finish(it)) }
            else -> Unit
        }
    }
}
