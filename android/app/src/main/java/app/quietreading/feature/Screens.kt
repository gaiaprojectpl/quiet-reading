package app.quietreading.feature

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.quietreading.R
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.colors
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.Screen

@Composable
fun HomeScreen() = Screen("Home") {
    EmptyState(R.drawable.ic_qs_book, "Your shelf is ready", "Add the book you’re reading now. It takes a few seconds.")
    QsButton("Add a book", onClick = {})
    QsButton("Import from Goodreads or StoryGraph", onClick = {}, kind = QsButtonKind.Text)
}

@Composable
fun LibraryScreen() = Screen("Library") {
    EmptyState(R.drawable.ic_qs_library, "Your library starts here", "Add books by photo, title or barcode, or bring them over from Goodreads.")
    QsButton("Add a book", onClick = {})
    QsButton("Import a library", onClick = {}, kind = QsButtonKind.Outline)
}

@Composable
fun AddBookScreen() = Screen("Add a book") {
    EmptyState(R.drawable.ic_qs_camera, "Three ways to add", "Photograph the cover, scan the barcode or search by title.")
    QsButton("Photograph the cover", onClick = {})
    QsButton("Scan the barcode", onClick = {}, kind = QsButtonKind.Secondary)
    QsButton("Search by title", onClick = {}, kind = QsButtonKind.Text)
}

@Composable
fun StatsScreen() = Screen("Stats") {
    EmptyState(R.drawable.ic_qs_stats, "Your stats will grow with you", "Update a page or finish a book.")
}

private val pickable = listOf(ThemeId.PeachSage, ThemeId.ClayCream, ThemeId.BlushIvory, ThemeId.LavenderMist)

@Composable
fun SettingsScreen(chosen: ThemeId, onChoose: (ThemeId) -> Unit) = Screen("Settings") {
    val c = QsTheme.colors
    Text("App theme", color = c.ink2, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(QsTheme.shapes.card)).background(c.surface)) {
        androidx.compose.foundation.layout.Column {
            pickable.forEach { id ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid)
                        .selectable(selected = id == chosen, role = Role.RadioButton) { onChoose(id) }
                        .padding(horizontal = QsSpace.s16, vertical = QsSpace.s12),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
                ) {
                    Swatch(id)
                    Text(id.displayName, color = c.ink, fontSize = 16.sp)
                    if (id.requiresPlus) {
                        Text(
                            "Plus", color = c.accentInk, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.background(c.soft, CircleShape).padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    if (id == chosen) Icon(painterResource(R.drawable.ic_qs_check), contentDescription = null, tint = c.accentInk)
                }
            }
        }
    }
    Text(
        "Dark theme uses Night and high contrast uses High contrast. Both are always free.",
        color = c.ink2, fontSize = 13.sp, lineHeight = 18.sp,
    )
}

@Composable
private fun Swatch(id: ThemeId) {
    val p = id.colors()
    Row(Modifier.size(width = 36.dp, height = 24.dp).clip(RoundedCornerShape(6.dp)).border(1.dp, p.line, RoundedCornerShape(6.dp))) {
        Box(Modifier.weight(1f).heightIn(min = 24.dp).background(p.bg))
        Box(Modifier.weight(1f).heightIn(min = 24.dp).background(p.soft))
        Box(Modifier.weight(1f).heightIn(min = 24.dp).background(p.accent))
    }
}
