package app.quietreading.feature.onboarding

import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.QsButton

/** Import (Flow 1, also reachable from Settings and empty states). */
fun NavGraphBuilder.onboardingGraph(nav: AppNav) {
    composable(Routes.IMPORT) { FlowScreen("Bring your books", onBack = nav::back) {} }
}

/** Flow 1 · First launch. */
@Composable
fun OnboardingFlow(onFinish: () -> Unit) {
    FlowScreen("Welcome", actions = { QsButton("Start", onFinish) }) {}
}
