package app.quietreading.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.navigation.NavHostController
import app.quietreading.data.ReadingStatus

/** Route names. Feature areas register their own screens in `feature/<area>/…Graph.kt`. */
object Routes {
    const val HOME = "home"
    const val LIBRARY = "library"
    const val STATS = "stats"
    const val SETTINGS = "settings"
    const val BOOK = "book/{id}"
    fun book(id: Long) = "book/$id"
    const val ADD = "add/{mode}"
    fun add(mode: String) = "add/$mode"
    const val IMPORT = "import"

    /** Screens that show the tab bar / rail. */
    val tabs = setOf(HOME, LIBRARY, STATS, SETTINGS)
}

/** Navigation helpers shared by every screen. */
class AppNav(val controller: NavHostController, val showAddSheet: () -> Unit) {
    /** Library opens on this shelf next time (Home › Up next › See all → Want to read). */
    var requestedShelf by mutableStateOf<ReadingStatus?>(null)

    fun back() { controller.popBackStack() }
    fun openBook(id: Long) = controller.navigate(Routes.book(id))
    fun openAdd(mode: String) = controller.navigate(Routes.add(mode))
    fun openImport() = controller.navigate(Routes.IMPORT)
    fun openTab(route: String) = controller.navigate(route) {
        popUpTo(Routes.HOME) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
    fun openLibrary(shelf: ReadingStatus?) {
        requestedShelf = shelf
        openTab(Routes.LIBRARY)
    }
}
