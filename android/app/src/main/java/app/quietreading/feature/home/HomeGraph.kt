package app.quietreading.feature.home

import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.TabScreen

/** Screens of this area. Placeholder until the area is ported from iOS. */
fun NavGraphBuilder.homeGraph(nav: AppNav) {
    composable(Routes.HOME) { HomeScreen(nav) }
}

@Composable
fun HomeScreen(nav: AppNav) {
    TabScreen("Home") {}
}
