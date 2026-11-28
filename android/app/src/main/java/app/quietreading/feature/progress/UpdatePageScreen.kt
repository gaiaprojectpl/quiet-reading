package app.quietreading.feature.progress

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import app.quietreading.R
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.data.ReadingTime
import app.quietreading.data.SessionEntity
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsSegmented
import app.quietreading.feature.book.LabeledField
import app.quietreading.feature.book.QsTextField
import app.quietreading.feature.book.bookScope
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Flow 3 › Step 2 · Update page (+ "Page is higher than the book").
 * Progress is typed – the number keyboard opens straight away. Finished + Update sit 24 dp above the keyboard.
 */
@Composable
fun UpdatePageScreen(book: Book, onClose: () -> Unit, onFinish: () -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    val notifier = LocalNotifier.current
    val pages = book.pageCount
    var percentMode by rememberSaveable { mutableStateOf(false) }
    var value by rememberSaveable { mutableStateOf(if (book.currentPage > 0) book.currentPage.toString() else "") }
    var note by rememberSaveable { mutableStateOf("") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    val number = value.toIntOrNull()
    val newPage: Int? = number?.let { v -> if (!percentMode) v else pages?.let { (it * min(v, 100) / 100.0).roundToInt() } }
    val tooHigh = pages != null && number != null && (if (percentMode) number > 100 else number > pages)

    val helper: String? = when {
        tooHigh && pages != null -> if (!percentMode) "This book has $pages pages." else "Up to 100%."
        newPage == null -> null
        else -> buildList {
            val since = newPage - book.currentPage
            if (since > 0) add(if (since == 1) "1 page since last time" else "$since pages since last time")
            book.minutesLeft(newPage)?.let { add(ReadingTime.left(it).lowercase()) }
        }.joinToString(" · ").ifEmpty { null }
    }

    fun save() {
        val page = newPage ?: return
        if (tooHigh) return
        val target = max(0, page)
        val previous = book.entity
        if (target == previous.currentPage && note.isBlank()) { onClose(); return }
        val updated = previous.copy(currentPage = target, lastUpdated = System.currentTimeMillis(),
            status = if (book.status == ReadingStatus.Read) previous.status else ReadingStatus.Reading.raw)
        val noteText = note.trim()
        onClose()
        bookScope.launch {
            val sessionId = library.dao.insert(SessionEntity(bookId = book.id, fromPage = previous.currentPage, toPage = target, note = noteText.ifEmpty { null }))
            library.dao.update(updated)
            // Flow 3 › Step 3 · Saved: "Page 168 saved · About 2 h 50 min left. Lovely." with Undo.
            val left = Book(updated, book.sessions).minutesLeft()
            notifier.show("Page $target saved", (left?.let { ReadingTime.left(it) + ". " } ?: "") + "Lovely.", actionTitle = "Undo") {
                bookScope.launch {
                    library.dao.delete(SessionEntity(id = sessionId, bookId = book.id, fromPage = 0, toPage = 0))
                    library.dao.update(previous)
                }
            }
        }
    }

    FlowScreen(
        title = null,
        onBack = onClose,
        backLabel = "Close",
        closeInstead = true,
        actions = {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                if (tooHigh) {
                    QsButton("Edit page", { runCatching { focus.requestFocus() } }, Modifier.weight(1f), kind = QsButtonKind.Secondary)
                    QsButton("Mark as finished", onFinish, Modifier.weight(1f))
                } else {
                    QsButton("Finished", onFinish, Modifier.weight(1f), kind = QsButtonKind.Secondary)
                    QsButton("Update", ::save, Modifier.weight(1f), enabled = newPage != null)
                }
            }
        },
    ) {
        Text("Where are you now?", style = QsTheme.headline(24), color = c.ink, modifier = Modifier.headingSemantics())
        Text(book.title, style = QsType.subheadline, color = c.ink2)
        if (pages != null) {
            QsSegmented(listOf(false to "Page", true to "Percent"), percentMode) { pct ->
                if (pct != percentMode) {
                    newPage?.let { cur -> value = (if (pct) (cur.toDouble() / pages * 100).roundToInt() else cur).toString() }
                    percentMode = pct
                }
            }
        }
        LabeledField(if (percentMode) "Percent" else "Page") {
            QsTextField(
                value, { v -> value = v.filter { it.isDigit() }.take(5) },
                placeholder = if (percentMode) "Percent" else "Page",
                number = true, error = tooHigh, textStyle = QsTheme.headline(20), focusRequester = focus,
            ) {
                if (pages != null) Text(if (percentMode) "%" else "of $pages", style = QsType.body, color = c.ink2)
                if (tooHigh) QsIcon(R.drawable.ic_qs_alert, tint = c.error, size = QsSize.iconM)
            }
            if (helper != null) Text(helper, style = QsType.footnote, color = if (tooHigh) c.error else c.ink2)
        }
        if (tooHigh && pages != null) InfoBanner("This book has $pages pages. Did you finish it?", error = true)
        LabeledField("Note (optional)") {
            QsTextField(note, { note = it }, placeholder = "Note (optional)", singleLine = false, minLines = 1)
        }
    }
}

internal fun Modifier.headingSemantics() = semantics { heading() }
