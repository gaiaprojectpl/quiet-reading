package app.quietreading.feature.add

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.components.FlowScreen

fun NavGraphBuilder.addGraph(nav: AppNav) {
    composable(Routes.ADD) { entry -> FlowScreen("Add a book", onBack = nav::back) {} }
}

/** The Add sheet (search, scan barcode, photograph cover, type, import). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSheet(nav: AppNav, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {}
}
