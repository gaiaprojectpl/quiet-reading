package app.quietreading.feature.add

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import kotlinx.coroutines.launch

/** Flow 2 · Add a book: how the book is found. Route value in "add/{mode}". */
enum class AddMode(val route: String) {
    Cover("cover"), Barcode("barcode"), Type("type");

    companion object { fun of(raw: String?) = entries.firstOrNull { it.route == raw } ?: if (raw == "search") Type else Cover }
}

fun NavGraphBuilder.addGraph(nav: AppNav) {
    composable(Routes.ADD) { entry -> AddFlowScreen(AddMode.of(entry.arguments?.getString("mode")), nav) }
}

/**
 * Flow 2 › Step 2 · Add a book: a short sheet from the bottom with the ways to add,
 * only as tall as its content so it sits within thumb reach.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSheet(nav: AppNav, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    fun choose(action: () -> Unit) {
        scope.launch { state.hide() }.invokeOnCompletion { onDismiss(); action() }
    }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = c.bg,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            Text("Add a book", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
            QsListCard(rows = listOf(
                { QsListRow(R.drawable.ic_qs_camera, "Photograph the cover", subtitle = "Read on your phone, nothing uploaded") { choose { nav.openAdd(AddMode.Cover.route) } } },
                { QsListRow(R.drawable.ic_qs_barcode, "Scan the barcode") { choose { nav.openAdd(AddMode.Barcode.route) } } },
                { QsListRow(R.drawable.ic_qs_search, "Search by title or author") { choose { nav.openAdd(AddMode.Type.route) } } },
            ))
            QsListCard(rows = listOf(
                { QsListRow(R.drawable.ic_qs_file, "Import a library", subtitle = "From Goodreads or StoryGraph") { choose { nav.openImport() } } },
            ))
        }
    }
}
