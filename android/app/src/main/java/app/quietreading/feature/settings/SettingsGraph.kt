package app.quietreading.feature.settings

import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.TabScreen

/** Screens of this area. Placeholder until the area is ported from iOS. */
fun NavGraphBuilder.settingsGraph(nav: AppNav) {
    composable(Routes.SETTINGS) { SettingsScreen(nav) }
}

@Composable
fun SettingsScreen(nav: AppNav) {
    TabScreen("Settings") {}
}
