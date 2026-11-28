package app.quietreading.feature.onboarding

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.semibold

/** Import (Flow 10 › B4), reachable from Home, Library, Settings and empty states. */
fun NavGraphBuilder.onboardingGraph(nav: AppNav) {
    composable(Routes.IMPORT) { ImportLibraryScreen(onClose = nav::back) }
}

/**
 * Importing your library: opens the file picker, then shows progress.
 * "Keep using the app" closes this screen; a notification says when it's done.
 */
@Composable
fun ImportLibraryScreen(onClose: () -> Unit) {
    val c = QsTheme.colors
    val s = ImportSession
    val context = LocalContext.current
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    var started by rememberSaveable { mutableStateOf(false) }
    var askedOnce by rememberSaveable { mutableStateOf(false) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) { ImportSession.start(context, uri, env, notifier); started = true }
    }
    LaunchedEffect(Unit) { if (!askedOnce) { askedOnce = true; picker.launch(CsvTypes) } }
    LaunchedEffect(s.phase) { if (s.phase == ImportSession.Phase.Finished && started) onClose() }
    val running = started && s.phase != ImportSession.Phase.Failed

    FlowScreen(
        "Importing your library", onBack = onClose, backLabel = "Cancel", closeInstead = true,
        actions = {
            if (running) QsButton("Keep using the app", onClose, kind = QsButtonKind.Secondary)
            else QsButton("Choose a file", { picker.launch(CsvTypes) })
        },
    ) {
        if (running) {
            if (s.sourceName.isNotEmpty()) Text("${s.total} books from ${s.sourceName}", style = QsType.subheadline, color = c.ink2)
            QsProgressBar(if (s.phase == ImportSession.Phase.Finished) 1f else s.fraction)
            Text(listOfNotNull("${s.done} of ${s.total}", s.timeLeftText).joinToString(" · "), style = QsType.subheadline.semibold(), color = c.ink)
            Text("You can leave this screen. We’ll let you know when your library is ready, and books appear as they arrive.", style = QsType.subheadline, color = c.ink2)
        } else {
            Text("Choose the CSV file you exported from Goodreads (My Books › Import and export) or StoryGraph (Manage account).", style = QsType.subheadline, color = c.ink2)
        }
    }
    if (started && s.phase == ImportSession.Phase.Failed) {
        CouldNotReadDialog(onTryAgain = { started = false; s.reset(); picker.launch(CsvTypes) }, onDismiss = { started = false; s.reset() })
    }
}
