package app.quietreading.feature.stats

import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.TabScreen

/** Screens of this area. Placeholder until the area is ported from iOS. */
fun NavGraphBuilder.statsGraph(nav: AppNav) {
    composable(Routes.STATS) { StatsScreen(nav) }
}

@Composable
fun StatsScreen(nav: AppNav) {
    TabScreen("Stats") {}
}
