package app.quietreading.feature.settings

import android.text.format.DateUtils
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import app.quietreading.R
import app.quietreading.data.Keys
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsCard
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium

/** Settings › Sources: the last import, and import again (duplicates are skipped). */
@Composable
fun SourcesScreen(onBack: () -> Unit, onImport: () -> Unit) {
    val c = QsTheme.colors
    val (lastImport, _) = rememberPref(Keys.lastImport, 0L)
    val (source, _) = rememberPref(Keys.lastImportSource, "")
    val context = LocalContext.current
    FlowScreen("Sources", onBack = onBack, backLabel = "Settings") {
        if (lastImport > 0) {
            val whenText = DateUtils.formatDateTime(context, lastImport, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_SHOW_TIME or DateUtils.FORMAT_ABBREV_MONTH)
            QsListCard(rows = listOf({ QsListRow(R.drawable.ic_qs_file, source, subtitle = "Imported $whenText") }))
        }
        Text("Import again any time. Books already on your shelf are skipped, so nothing doubles.", style = QsType.subheadline, color = c.ink2)
        QsButton("Import a library", onImport, kind = QsButtonKind.Secondary)
    }
}

/** Settings › Fonts and licences: the heading fonts are open source (SIL Open Font License). */
@Composable
fun LicencesScreen(onBack: () -> Unit) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val files = remember { context.assets.list("licences")?.sorted().orEmpty() }
    FlowScreen("Fonts and licences", onBack = onBack, backLabel = "Settings") {
        Text(
            "Quiet Reading uses these open-source fonts and Tabler Icons (MIT licence). Thank you to their makers.",
            style = QsType.subheadline, color = c.ink2,
        )
        files.forEach { file ->
            var open by remember { mutableStateOf(false) }
            val text = remember(file) { runCatching { context.assets.open("licences/$file").bufferedReader().readText() }.getOrDefault("") }
            val name = file.removeSuffix(".txt").removeSuffix("-OFL").replace(Regex("([a-z])([A-Z])"), "$1 $2")
            QsCard {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).pressable(label = if (open) "Hide licence" else "Show licence") { open = !open },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(name, style = QsType.body.medium(), color = c.ink, modifier = Modifier.semantics { heading() })
                        Text("SIL Open Font License 1.1", style = QsType.footnote, color = c.ink2)
                    }
                    QsIcon(R.drawable.ic_qs_chevron, tint = c.ink2, size = QsSize.iconS)
                }
                AnimatedVisibility(open) {
                    Text(text.trim(), style = QsType.caption.copy(fontFamily = FontFamily.Monospace), color = c.ink2,
                        modifier = Modifier.horizontalScroll(rememberScrollState()).padding(top = QsSpace.s4))
                }
            }
        }
    }
}
