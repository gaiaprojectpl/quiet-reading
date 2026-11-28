package app.quietreading.feature.progress

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.ChipFlow
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsStarRating
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import app.quietreading.feature.book.QsTextField
import app.quietreading.feature.book.dayMonth
import app.quietreading.feature.book.starsText
import kotlinx.coroutines.launch

private val suggestedMoods = listOf("Cozy", "Slow", "Hopeful", "Sad", "Re-read")

/**
 * Flow 3 › Step 4 · Finished moment. [onDone] gets whether something is waiting on Want to read
 * (then What's next follows).
 */
@Composable
fun FinishedScreen(book: Book, wantToRead: List<Book>, onDone: (hasNext: Boolean) -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    val scope = rememberCoroutineScope()
    var stars by rememberSaveable { mutableStateOf(book.stars) }
    val moods = remember { mutableStateListOf<String>().apply { addAll(book.moods) } }
    val custom = remember { mutableStateListOf<String>().apply { addAll(book.moods.filter { it !in suggestedMoods }) } }
    var adding by remember { mutableStateOf(false) }
    var newMood by remember { mutableStateOf("") }

    fun complete(saveFeelings: Boolean) {
        scope.launch {
            val chosen = (suggestedMoods + custom).filter { it in moods }
            if (saveFeelings) library.finish(book, stars, chosen) else library.finish(book, book.stars, book.moods)
            onDone(wantToRead.any { it.id != book.id })
        }
    }

    FlowScreen(
        title = null,
        actions = {
            QsButton("Save", { complete(true) })
            QsButton("Skip for now", { complete(false) }, kind = QsButtonKind.Text)
        },
    ) {
        Column(Modifier.fillMaxWidth().gentleAppear(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            BookCover(book.coverFile, book.title, width = 150.dp)
            Text("FINISHED · ${dayMonth(System.currentTimeMillis()).uppercase()}", style = QsType.caption.semibold().copy(letterSpacing = 0.72.sp()), color = c.ink2)
            Text("You finished ${book.title}", style = QsTheme.headline(28), color = c.ink, textAlign = TextAlign.Center, modifier = Modifier.headingSemantics())
            QsStarRating(stars) { stars = it }
            Text(stars?.let { "${starsText(it)} · tap a star twice for a half" } ?: "Tap a star twice for a half", style = QsType.footnote, color = c.ink2)
        }
        Column(Modifier.fillMaxWidth().gentleAppear(delay = 150), verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            Text("How did it feel?", style = QsType.subheadline.semibold(), color = c.ink, modifier = Modifier.headingSemantics())
            ChipFlow {
                (suggestedMoods + custom).forEach { mood ->
                    QsChip(mood, selected = mood in moods) { if (mood in moods) moods.remove(mood) else moods.add(mood) }
                }
                QsChip("+ Add", modifier = Modifier.semantics { contentDescription = "Add a feeling" }) { adding = true }
            }
        }
    }

    if (adding) {
        AlertDialog(
            onDismissRequest = { adding = false; newMood = "" },
            containerColor = c.surface,
            title = { Text("Add a feeling", style = QsTheme.headline(22), color = c.ink) },
            text = { QsTextField(newMood, { newMood = it }, placeholder = "Feeling") },
            confirmButton = {
                TextButton({
                    val m = newMood.trim()
                    if (m.isNotEmpty() && m !in custom && m !in suggestedMoods) custom.add(m)
                    if (m.isNotEmpty() && m !in moods) moods.add(m)
                    newMood = ""; adding = false
                }) { Text("Add", color = c.accentInk, style = QsType.body.semibold()) }
            },
            dismissButton = { TextButton({ adding = false; newMood = "" }) { Text("Cancel", color = c.accentInk, style = QsType.body) } },
        )
    }
}

/** Flow 3 › Step 5 · What's next: pick from Want to read, or let it wait. */
@Composable
fun WhatNextScreen(wantToRead: List<Book>, onDone: () -> Unit) {
    val c = QsTheme.colors
    val library = LocalApp.current.library
    val scope = rememberCoroutineScope()
    FlowScreen(
        title = "What’s next?",
        actions = { QsButton("Choose later", onDone, kind = QsButtonKind.Secondary) },
    ) {
        Text("From your Want to read shelf", style = QsType.subheadline, color = c.ink2)
        QsListCard(rows = wantToRead.sortedBy { it.dateAdded }.take(5).map { book ->
            @Composable {
                Row(
                    Modifier.fillMaxWidth()
                        .pressable(label = "Start reading") { scope.launch { library.setStatus(book, ReadingStatus.Reading); onDone() } }
                        .semantics(mergeDescendants = true) {}
                        .padding(QsSpace.s12),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
                ) {
                    BookCover(book.coverFile, book.title, width = 52.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
                        Text(book.title, style = QsTheme.headline(18), color = c.ink)
                        Text(book.pageCount?.let { "${book.author} · $it pages" } ?: book.author, style = QsType.footnote, color = c.ink2)
                    }
                }
            }
        })
    }
}

private fun Double.sp() = androidx.compose.ui.unit.TextUnit(this.toFloat(), androidx.compose.ui.unit.TextUnitType.Sp)
