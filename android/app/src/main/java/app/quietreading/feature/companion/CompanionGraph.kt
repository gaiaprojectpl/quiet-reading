package app.quietreading.feature.companion

import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace

object CompanionRoutes {
    const val CHAT = "companion"
    const val SETTINGS = "companion/settings"
}

/** Flow 12 · Astrid: the chat (consent first) and Astrid & privacy. */
fun NavGraphBuilder.companionGraph(nav: AppNav) {
    composable(CompanionRoutes.CHAT) { CompanionScreen(nav) }
    composable(CompanionRoutes.SETTINGS) { CompanionSettingsScreen(nav) }
}

/**
 * Floating Astrid button over the tab screens: bottom-right, 20 dp from the edge and 16 dp above the tab bar.
 * In the rail (unfolded foldables) it docks above the navigation at 48 dp.
 */
@Composable
fun CompanionButtonSlot(nav: AppNav, modifier: Modifier = Modifier, inRail: Boolean = false) {
    val open = { nav.controller.navigate(CompanionRoutes.CHAT) { launchSingleTop = true } }
    if (inRail) CompanionButton(QsSize.button, modifier.padding(bottom = QsSpace.s12), onClick = open)
    else CompanionButton(modifier = modifier.padding(end = QsSpace.s20, bottom = QsSpace.s16), onClick = open)
}
