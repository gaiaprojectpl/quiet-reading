package app.quietreading.feature.book

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.data.Book
import app.quietreading.data.BookEntity
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.ChipFlow
import app.quietreading.designsystem.components.Notifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.medium
import kotlinx.coroutines.launch

/** Moves a book to a shelf and shows "Moved to …" with Undo (Flow 7 › Step 4). */
internal fun moveBook(book: Book, status: ReadingStatus, library: app.quietreading.data.Library, notifier: Notifier) {
    if (status == book.status) return
    val previous: BookEntity = book.entity
    bookScope.launch {
        library.save(previous.copy(
            status = status.raw,
            dateFinished = if (status == ReadingStatus.Read) (previous.dateFinished ?: System.currentTimeMillis()) else previous.dateFinished,
            currentPage = if (status == ReadingStatus.Read) (previous.pageCount ?: previous.currentPage) else previous.currentPage,
        ))
        notifier.show("Moved to ${status.shelfName}", "You can move it back any time.", NoticeKind.Info, actionTitle = "Undo") {
            bookScope.launch { library.dao.update(previous) }
        }
    }
}

/** Flow 7 › Step 3 · Move to shelf (+ Remove from library). */
@Composable
fun MoveToShelfSheet(book: Book, notifier: Notifier, onDismiss: () -> Unit, onRemove: () -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    QsSheet(onDismiss) {
        Text("Move to shelf", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
        SheetGroup {
            ReadingStatus.shelves.forEachIndexed { i, status ->
                if (i > 0) HorizontalDivider(thickness = 0.75.dp, color = c.line)
                SheetRow(status.icon, status.bookLabel, c.ink, c.soft2, c.accentInk, selected = book.status == status) {
                    onDismiss()
                    moveBook(book, status, library, notifier)
                }
            }
        }
        SheetGroup {
            SheetRow(R.drawable.ic_qs_trash, "Remove from library", c.error, c.errorSoft, c.error, selected = false) {
                onDismiss(); onRemove()
            }
        }
    }
}

@Composable
private fun SheetGroup(content: @Composable () -> Unit) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card - 4.dp)
    Column(Modifier.fillMaxWidth().clip(shape).background(c.surface).border(0.75.dp, c.line, shape)) { content() }
}

@Composable
private fun SheetRow(icon: Int, title: String, tint: Color, tile: Color, iconTint: Color, selected: Boolean, onClick: () -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).selectable(selected, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = QsSpace.s16, vertical = QsSpace.s12),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(QsSpace.s32).background(tile, RoundedCornerShape(QsTheme.shapes.inner + 2.dp)), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = iconTint, size = QsSize.iconM)
        }
        Text(title, style = QsType.body.medium(), color = tint, modifier = Modifier.weight(1f))
        if (selected) QsIcon(R.drawable.ic_qs_check, tint = c.accentInk, size = QsSize.iconM + 2.dp)
    }
}

/** "How did it feel?" chips, editable from book details. */
@Composable
fun MoodsSheet(book: Book, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    val scope = rememberCoroutineScope()
    val base = listOf("Cozy", "Slow", "Hopeful", "Sad", "Re-read", "Dark", "Funny")
    val options = base + book.moods.filter { it !in base }
    val moods = remember { mutableStateListOf<String>().apply { addAll(book.moods) } }
    QsSheet(onDismiss) {
        Text("How did it feel?", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
        ChipFlow {
            options.forEach { m -> QsChip(m, selected = m in moods) { if (m in moods) moods.remove(m) else moods.add(m) } }
        }
        QsButton("Save", {
            scope.launch {
                library.save(book.entity.copy(moods = options.filter { it in moods }.joinToString("|")))
                onDismiss()
            }
        }, Modifier.padding(top = QsSpace.s12))
    }
}
