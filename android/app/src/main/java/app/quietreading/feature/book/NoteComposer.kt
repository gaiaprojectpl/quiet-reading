package app.quietreading.feature.book

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.SessionEntity
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.QsButton
import kotlinx.coroutines.launch

/**
 * Book details › Notes › "Add a note" (typed). The note is a session on the chosen page (from = to),
 * so it shows in Notes and stays with the book. Saving is silent.
 * (Writing with a stylus comes with the foldable phase.)
 */
@Composable
fun NoteComposerScreen(book: Book, onClose: () -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    val scope = rememberCoroutineScope()
    var text by rememberSaveable { mutableStateOf("") }
    var page by rememberSaveable { mutableStateOf(if (book.currentPage > 0) book.currentPage.toString() else "") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    FlowScreen(
        title = null,
        onBack = onClose,
        backLabel = "Close",
        closeInstead = true,
        actions = {
            QsButton("Save note", {
                val p = page.toIntOrNull() ?: book.currentPage
                val note = text.trim()
                scope.launch {
                    library.dao.insert(SessionEntity(bookId = book.id, fromPage = p, toPage = p, note = note))
                    onClose()
                }
            }, enabled = text.isNotBlank())
        },
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            Text("New note", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.weight(1f).semantics { heading() })
            QsTextField(page, { v -> page = v.filter { it.isDigit() }.take(5) }, placeholder = "Page", number = true,
                modifier = Modifier.width(QsSpace.s80 + QsSpace.s16), contentPadding = QsSpace.s12, textStyle = QsType.subheadline)
        }
        QsTextField(text, { text = it }, placeholder = "What’s on your mind about this book?", singleLine = false, minLines = 4, focusRequester = focus)
    }
}
