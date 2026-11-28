package app.quietreading.feature.library

import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.TabScreen

/** Screens of this area. Placeholder until the area is ported from iOS. */
fun NavGraphBuilder.libraryGraph(nav: AppNav) {
    composable(Routes.LIBRARY) { LibraryScreen(nav) }
}

@Composable
fun LibraryScreen(nav: AppNav) {
    TabScreen("Library") {}
}
