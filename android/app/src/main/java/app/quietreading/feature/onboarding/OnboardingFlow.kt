package app.quietreading.feature.onboarding

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.CoverFrame
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.QsLogo
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.semibold

/** File types the system picker offers for a Goodreads / StoryGraph export. */
val CsvTypes = arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/csv", "application/vnd.ms-excel", "text/*")

private enum class Step { Sources, Importing, Widget, NotReady }

/** Flow 1 · First launch & import: Landing → Bring your books → Importing → Add your widget → Home. */
@Composable
fun OnboardingFlow(onFinish: () -> Unit) {
    val path = remember { mutableStateListOf<Step>() }
    BackHandler(enabled = path.isNotEmpty()) { path.removeAt(path.lastIndex) }
    val back = { path.removeAt(path.lastIndex); Unit }

    when (path.lastOrNull()) {
        null -> LandingStep(onGetStarted = { path.add(Step.Sources) }, onHaveAccount = { path.add(Step.NotReady) })
        Step.Sources -> SourcesStep(
            onBack = back,
            onImportStarted = { path.add(Step.Importing) },
            onStartFresh = { path.add(Step.Widget) },
            onNotReady = { path.add(Step.NotReady) },
        )
        Step.Importing -> ImportingStep(onBack = back, onContinue = { if (path.lastOrNull() == Step.Importing) path.add(Step.Widget) })
        Step.Widget -> WidgetStep(onBack = back, onDone = onFinish)
        Step.NotReady -> FlowScreen(null, onBack = back, actions = { QsButton("Go back", back) }) {
            EmptyState(R.drawable.ic_qs_info, "This comes in a later update", "For now you can import a CSV file or start fresh.")
        }
    }
}

/** Screen title in the heading font (30 in Figma). */
@Composable
fun OnboardingTitle(text: String) {
    Text(text, style = QsTheme.headline(30), color = QsTheme.colors.ink, modifier = Modifier.semantics { heading() })
}

// Step 1 · Landing

@Composable
private fun LandingStep(onGetStarted: () -> Unit, onHaveAccount: () -> Unit) {
    val c = QsTheme.colors
    FlowScreen(null, actions = {
        QsButton("Get started", onGetStarted)
        QsButton("I already have an account", onHaveAccount, kind = QsButtonKind.Secondary)
        Text("Free to use · Plus themes are optional", style = QsType.footnote, color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }) {
        QsLogo()
        CoverFan()
        Text("Your reading life, quietly on your home screen.", style = QsTheme.headline(30), color = c.ink, modifier = Modifier.semantics { heading() })
        Text("Add a book with one photo. Update in one tap. No streaks, no noise.", style = QsType.body, color = c.ink2)
    }
}

/** The four sample covers fanned over a soft circle (Figma: Landing › Covers). Illustration geometry from the design. */
@Composable
fun CoverFan(modifier: Modifier = Modifier) {
    val covers = listOf(
        Triple(R.drawable.cover_quiet_orchard, -115 to 12, 8f),
        Triple(R.drawable.cover_salt_pages, -18 to -36, -5f),
        Triple(R.drawable.cover_north_library, 52 to -4, 3f),
        Triple(R.drawable.cover_winter_tea, 126 to -46, -9f),
    )
    Box(modifier.fillMaxWidth().height(300.dp).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
        Box(Modifier.size(250.dp).background(QsTheme.colors.soft, CircleShape))
        covers.forEach { (res, xy, angle) ->
            CoverFrame(ImageBitmap.imageResource(res), "", Modifier.offset(xy.first.dp, xy.second.dp).rotate(angle), width = 96.dp)
        }
    }
}

// Step 2 · Bring your books

@Composable
private fun SourcesStep(onBack: () -> Unit, onImportStarted: () -> Unit, onStartFresh: () -> Unit, onNotReady: () -> Unit) {
    val context = LocalContext.current
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) {
            ImportSession.start(context, uri, env, notifier)
            onImportStarted()
        }
    }
    FlowScreen(null, onBack = onBack) {
        OnboardingTitle("Bring your books")
        Text("Choose where your reading lives today. You can add more later.", style = QsType.subheadline, color = QsTheme.colors.ink2)
        QsListCard(rows = listOf(
            { QsListRow(R.drawable.ic_qs_link, "Goodreads profile link", "Reads your shelves · public profiles", onClick = onNotReady) },
            { QsListRow(R.drawable.ic_qs_file, "Goodreads CSV file", "Full history from a Goodreads export") { picker.launch(CsvTypes) } },
            { QsListRow(R.drawable.ic_qs_file, "StoryGraph CSV file", "From StoryGraph › Manage account") { picker.launch(CsvTypes) } },
            { QsListRow(R.drawable.ic_qs_library, "Hardcover account", "Live sync with your API token", onClick = onNotReady) },
            { QsListRow(R.drawable.ic_qs_plus, "Start fresh", "Add books by photo or search", onClick = onStartFresh) },
        ))
        InfoBanner("We never ask for your Goodreads password.")
    }
}

// Step 3 · Importing your books

@Composable
private fun ImportingStep(onBack: () -> Unit, onContinue: () -> Unit) {
    val c = QsTheme.colors
    val s = ImportSession
    val context = LocalContext.current
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) ImportSession.start(context, uri, env, notifier)
    }
    LaunchedEffect(s.phase) { if (s.phase == ImportSession.Phase.Finished) onContinue() }

    FlowScreen(null, onBack = onBack, actions = {
        QsButton("Continue in the background", onContinue, kind = QsButtonKind.Secondary)
    }) {
        OnboardingTitle("Importing your books")
        Text(
            "${s.done} of ${s.total}", style = QsTheme.headline(40), color = c.accentInk,
            modifier = Modifier.semantics { contentDescription = "${s.done} of ${s.total} books matched" },
        )
        QsProgressBar(s.fraction)
        Text("Matching editions and covers…", style = QsType.subheadline, color = c.ink2)
        if (s.recentCovers.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s20)) {
                s.recentCovers.forEach { BookCover(it, "", width = QsSize.coverM) }
            }
        }
        if (s.missingCovers > 0) InfoBanner("${s.missingCovers} books have no cover yet. You can add your own photo later.")
    }
    if (s.phase == ImportSession.Phase.Failed) CouldNotReadDialog(onTryAgain = { s.reset(); picker.launch(CsvTypes) }, onDismiss = { s.reset(); onBack() })
}

/** "We couldn’t read this file" with Help and Try again. */
@Composable
fun CouldNotReadDialog(onTryAgain: () -> Unit, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    val uri = LocalUriHandler.current
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        title = { Text("We couldn’t read this file", style = QsTheme.headline(22), color = c.ink) },
        text = { Text("Make sure it’s the CSV from Goodreads › My Books › Import and export, or from StoryGraph › Manage account.", style = QsType.body, color = c.ink2) },
        confirmButton = { TextButton(onTryAgain) { Text("Try again", style = QsType.body.semibold(), color = c.accentInk) } },
        dismissButton = { TextButton({ uri.openUri("https://www.goodreads.com/review/import") }) { Text("Help", style = QsType.body, color = c.accentInk) } },
    )
}

// Step 4 · Add your reading widget

@Composable
private fun WidgetStep(onBack: () -> Unit, onDone: () -> Unit) {
    val c = QsTheme.colors
    FlowScreen(null, onBack = onBack, actions = {
        QsButton("Done", onDone)
        QsButton("Remind me later", onDone, kind = QsButtonKind.Text)
    }) {
        OnboardingTitle("Add your reading widget")
        Box(Modifier.fillMaxWidth().background(c.soft, RoundedCornerShape(QsTheme.shapes.card)).padding(QsSpace.s20), contentAlignment = Alignment.Center) {
            WidgetPreview()
        }
        StepRow(1, "Touch and hold an empty spot on your Home screen")
        StepRow(2, "Tap Widgets")
        StepRow(3, "Find Quiet Reading and drag a widget into place")
    }
}

@Composable
private fun StepRow(number: Int, text: String) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) { contentDescription = "Step $number. $text" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(QsSize.iconL + QsSpace.s4).background(c.accent, CircleShape), contentAlignment = Alignment.Center) {
            Text("$number", style = QsType.subheadline.semibold(), color = c.onAccent)
        }
        Text(text, style = QsType.subheadline, color = c.ink, modifier = Modifier.weight(1f))
    }
}

/** Small widget mock-up (Figma: Widget · small, 158 × 158). Illustration only. */
@Composable
private fun WidgetPreview() {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier.size(158.dp).background(c.surface, shape).border(0.75.dp, c.line, shape).padding(QsSpace.s12)
            .clearAndSetSemantics { contentDescription = "Example of the reading widget, showing your current book with an Update button" },
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            CoverFrame(ImageBitmap.imageResource(R.drawable.cover_quiet_orchard), "", width = QsSpace.s40)
            Box(Modifier.height(36.dp).background(c.accent, CircleShape).padding(horizontal = QsSpace.s12), contentAlignment = Alignment.Center) {
                Text("Update", style = QsType.subheadline.semibold(), color = c.onAccent)
            }
        }
        Text("The Quiet Orchard", style = QsTheme.headline(13), color = c.ink, maxLines = 1)
        QsProgressBar(0.46f)
        Text("p. 142 · 46%", style = QsType.caption2, color = c.ink2)
    }
}
