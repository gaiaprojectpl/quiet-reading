package app.quietreading.feature.book

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.QuoteEntity
import app.quietreading.data.ReadingStatus
import app.quietreading.data.ReadingTime
import app.quietreading.data.SessionEntity
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsCard
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.QsSegmented
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import app.quietreading.feature.progress.gentleAppear
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

private enum class DetailTab { Progress, Quotes, Notes }

/** Flow 7 › Step 2 · Book details: header with the shelf chip, progress, notes, Started / Moods / Source. */
@Composable
fun BookDetailScreen(book: Book, nav: AppNav) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val app = LocalApp.current
    val library = app.library
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    var tab by rememberSaveable { mutableStateOf(DetailTab.Progress) }
    var showMove by remember { mutableStateOf(false) }
    var showMoods by remember { mutableStateOf(false) }
    var showMore by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf(false) }
    var coverMenu by remember { mutableStateOf(false) }
    var savingCover by remember { mutableStateOf(false) }

    val notes = book.sessions.filter { !it.note.isNullOrBlank() }.sortedByDescending { it.date }
    val quotes = book.quotes.sortedByDescending { it.date }

    // Cover photo: take one of the book in your hands, or pick one from your photos. Saving is silent.
    fun setCover(bytes: ByteArray?, bitmap: Bitmap?) {
        savingCover = true
        scope.launch {
            val name = if (bitmap != null) app.covers.save(bitmap) else bytes?.let { app.covers.save(it) }
            if (name != null) {
                book.coverFile?.let { app.covers.delete(it) }
                library.save(book.entity.copy(coverFile = name))
            }
            savingCover = false
        }
    }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            val bytes = withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)?.use { it.readBytes() } }
            setCover(bytes, null)
        }
    }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bmp -> if (bmp != null) setCover(null, bmp) }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) takePhoto.launch(null)
        else notifier.show("Camera is off", "Choose a photo instead, or allow the camera in Settings.", NoticeKind.Info)
    }
    fun openCamera() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) takePhoto.launch(null)
        else cameraPermission.launch(Manifest.permission.CAMERA)
    }

    val actions: @Composable () -> Unit = {
        when (book.status) {
            ReadingStatus.Reading -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                QsButton("Update", { nav.controller.navigate(BookRoutes.update(book.id)) }, Modifier.weight(1f))
                QsButton("Finished", { nav.controller.navigate(BookRoutes.finish(book.id)) }, Modifier.weight(1f), kind = QsButtonKind.Secondary)
            }
            ReadingStatus.ToRead -> QsButton("Start reading", { moveBook(book, ReadingStatus.Reading, library, notifier) })
            else -> {}
        }
    }

    Column(
        Modifier.fillMaxSize().background(c.bg).statusBarsPadding().verticalScroll(rememberScrollState())
            .navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s4, bottom = QsSpace.s40),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        // Top bar: back, share, more.
        Row(Modifier.fillMaxWidth().padding(start = 0.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.padding(start = 0.dp)) { QsIconButton(R.drawable.ic_qs_arrow_left, "Back", onClick = nav::back) }
            Box(Modifier.weight(1f))
            QsIconButton(R.drawable.ic_qs_share, "Share") {
                val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, "I’m reading ${book.title}" + if (book.author.isNotBlank()) " by ${book.author}" else "")
                context.startActivity(Intent.createChooser(send, null))
            }
            Box {
                QsIconButton(R.drawable.ic_qs_more, "More") { showMore = true }
                DropdownMenu(showMore, { showMore = false }, containerColor = c.surface) {
                    DropdownMenuItem({ Text("Move to shelf", color = c.ink) }, { showMore = false; showMove = true })
                    DropdownMenuItem({ Text("Remove from library", color = c.error) }, { showMore = false; confirmRemove = true })
                }
            }
        }

        // Header: cover (tap to add/change), title, author, pages, shelf chip.
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                Box(Modifier.pressable(label = if (book.coverFile == null) "Add a cover photo" else "Change the cover") { coverMenu = true }
                    .semantics { contentDescription = if (book.coverFile == null) "Add a cover photo" else "Change the cover" },
                    contentAlignment = Alignment.Center) {
                    BookCover(book.coverFile, book.title, width = 112.dp)
                    if (savingCover) CircularProgressIndicator(color = c.ink, strokeWidth = 2.dp)
                }
                Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable { coverMenu = true }.semantics { }, contentAlignment = Alignment.Center) {
                    Text(if (book.coverFile == null) "Add cover" else "Change cover", style = QsType.footnote.semibold(), color = c.accentInk)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                Text(book.title, style = QsTheme.headline(24), color = c.ink, modifier = Modifier.semantics { heading() })
                if (book.author.isNotBlank()) Text(book.author, style = QsType.subheadline, color = c.ink2)
                book.pageCount?.let { Text("$it pages", style = QsType.footnote, color = c.ink2) }
                QsChip(book.status.bookLabel, selected = true, icon = book.status.icon) { showMove = true }
            }
        }

        QsSegmented(
            listOf(DetailTab.Progress to "Progress", DetailTab.Quotes to "Quotes · ${book.quotes.size}", DetailTab.Notes to "Notes"),
            tab,
        ) { tab = it }

        val fade = if (QsTheme.reduceMotion) 0 else QsMotion.base
        AnimatedContent(tab, transitionSpec = {
            val d = fade
            fadeIn(tween(d)) togetherWith fadeOut(tween(d))
        }, label = "tab") { t ->
            Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
                when (t) {
                    DetailTab.Progress -> {
                        if (book.status == ReadingStatus.Reading) {
                            QsCard {
                                val p = book.progress
                                val pages = book.pageCount
                                if (p != null && pages != null) {
                                    QsProgressBar(p)
                                    Text(progressLine(book, pages, p), style = QsType.footnote, color = c.ink2)
                                }
                                actions()
                            }
                        } else if (book.status == ReadingStatus.ToRead) actions()
                        NotesSummary(quotes, notes) { tab = DetailTab.Quotes }
                        InfoCard(book) { showMoods = true }
                    }
                    DetailTab.Quotes -> {
                        if (quotes.isEmpty()) {
                            EmptyState(R.drawable.ic_qs_quote, "No quotes yet", "When a line stays with you, save it here with a photo of the page.")
                        } else quotes.forEach { QuoteCard(it) }
                        QsButton("Add a quote", { nav.controller.navigate("quotes/add/${book.id}") })
                    }
                    DetailTab.Notes -> {
                        if (notes.isEmpty()) {
                            EmptyState(R.drawable.ic_qs_quote, "No notes yet", "Jot down a thought about this book. Notes stay with it.")
                        } else notes.forEach { n ->
                            NoteCard(n) {
                                bookScope.launch {
                                    if (n.fromPage == n.toPage) library.dao.delete(n) else library.dao.update(n.copy(note = null, noteDrawing = null))
                                }
                            }
                        }
                        QsButton("Add a note", { nav.controller.navigate(BookRoutes.note(book.id)) })
                    }
                }
            }
        }
    }

    if (showMove) MoveToShelfSheet(book, notifier, onDismiss = { showMove = false }, onRemove = { confirmRemove = true })
    if (showMoods) MoodsSheet(book) { showMoods = false }
    if (coverMenu) {
        QsSheet({ coverMenu = false }) {
            Text(if (book.coverFile == null) "Add a cover" else "Change the cover", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
            Text("Hold the book flat and fill the frame.", style = QsType.subheadline, color = c.ink2)
            QsListCard(rows = listOf(
                { QsListRow(R.drawable.ic_qs_camera, "Take a photo") { coverMenu = false; openCamera() } },
                { QsListRow(R.drawable.ic_qs_file, "Choose from your photos") {
                    coverMenu = false
                    pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                } },
            ))
        }
    }
    // Flow 7 › Remove a book
    if (confirmRemove) {
        AlertDialog(
            onDismissRequest = { confirmRemove = false },
            containerColor = c.surface,
            title = { Text("Remove “${book.title}”?", style = QsTheme.headline(22), color = c.ink) },
            text = { Text("Your progress, notes and quotes for this book will be deleted. This can’t be undone.", style = QsType.body, color = c.ink2) },
            confirmButton = {
                TextButton({
                    confirmRemove = false
                    nav.back()
                    bookScope.launch { library.delete(book) }
                }) { Text("Remove", color = c.error, style = QsType.body.semibold()) }
            },
            dismissButton = { TextButton({ confirmRemove = false }) { Text("Cancel", color = c.accentInk, style = QsType.body) } },
        )
    }
}

/** "p. 142 of 310 · 46% · about 3 h 20 min left" */
private fun progressLine(book: Book, pages: Int, progress: Float): String {
    var line = if (book.currentPage == 0) "Not started" else "p. ${book.currentPage} of $pages · ${(progress * 100).roundToInt()}%"
    book.minutesLeft()?.takeIf { it > 0 }?.let { line += " · " + ReadingTime.left(it).lowercase() }
    return line
}

/** "p. 98 · Cozy · from a page photo" */
private fun quoteMeta(q: QuoteEntity): String = listOfNotNull(
    q.page?.let { "p. $it" }, q.mood, if (q.fromPhoto) "from a page photo" else null,
).joinToString(" · ")

@Composable
private fun NotesSummary(quotes: List<QuoteEntity>, notes: List<SessionEntity>, onOpenQuotes: () -> Unit) {
    val c = QsTheme.colors
    val quote = quotes.firstOrNull()
    val latest = notes.firstOrNull()
    if (quote == null && latest == null) return
    QsCard(Modifier.then(if (quote != null) Modifier.pressable(label = "Open quotes", onClick = onOpenQuotes) else Modifier)) {
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s8), verticalAlignment = Alignment.CenterVertically) {
            QsIcon(R.drawable.ic_qs_quote, tint = c.accentInk, size = QsSize.iconM)
            Text("Notes & quotes · ${if (quote != null) quotes.size + notes.size else notes.size}", style = QsType.subheadline.semibold(), color = c.ink)
        }
        if (quote != null) {
            Text("“${quote.text}”", style = QsTheme.headline(17), color = c.ink, maxLines = 4)
            Text(quoteMeta(quote), style = QsType.footnote, color = c.ink2)
        } else if (latest != null) {
            Text("“${latest.note}”", style = QsTheme.headline(17), color = c.ink)
            Text("p. ${latest.toPage} · ${dayMonth(latest.date)}", style = QsType.footnote, color = c.ink2)
        }
    }
}

@Composable
private fun QuoteCard(q: QuoteEntity) {
    val c = QsTheme.colors
    val isNew = isRecent(q.date)
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(if (isNew) c.soft2 else c.surface).border(QsSize.stroke, c.line, shape)
            .padding(QsSpace.s16).semantics(mergeDescendants = true) {}.gentleAppear(),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            QsIcon(R.drawable.ic_qs_quote, tint = c.accentInk, size = QsSize.iconS, modifier = Modifier.padding(top = QsSpace.s2))
            Text("“${q.text}”", style = QsTheme.headline(15), color = c.ink)
        }
        Text(listOf(quoteMeta(q), if (isNew) "new" else "").filter { it.isNotEmpty() }.joinToString(" · "), style = QsType.footnote, color = c.ink2)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun NoteCard(n: SessionEntity, onDelete: () -> Unit) {
    val c = QsTheme.colors
    var menu by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Box {
        Column(
            Modifier.fillMaxWidth().clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape)
                .combinedClickable(onClick = {}, onLongClick = { menu = true }, onLongClickLabel = "Delete note")
                .semantics(mergeDescendants = true) { onClick("Delete note") { menu = true; true } }
                .padding(QsSpace.s16).gentleAppear(),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
        ) {
            Text(n.note.orEmpty(), style = QsType.body, color = c.ink)
            Text("p. ${n.toPage} · ${dayMonth(n.date)}", style = QsType.footnote, color = c.ink2)
        }
        DropdownMenu(menu, { menu = false }, containerColor = c.surface) {
            DropdownMenuItem({ Text("Delete note", color = c.error) }, { menu = false; onDelete() })
        }
    }
}

@Composable
private fun InfoCard(book: Book, onMoods: () -> Unit) {
    val rows = buildList<@Composable () -> Unit> {
        add { QsListRow(R.drawable.ic_qs_calendar, "Started", dayMonth(book.startedDate)) }
        val finished = book.dateFinished
        if (book.status == ReadingStatus.Read && finished != null) {
            val stars = book.stars ?: book.entity.rating?.toDouble()
            add { QsListRow(R.drawable.ic_qs_check, "Finished", dayMonth(finished, year = true) + (stars?.let { " · ★ ${starsText(it)}" } ?: "")) }
        }
        add { QsListRow(R.drawable.ic_qs_tag, "Moods", book.moods.ifEmpty { null }?.joinToString(" · ") ?: "Add how it felt", onClick = onMoods) }
        add { QsListRow(R.drawable.ic_qs_link, "Source", book.source.label) }
    }
    QsListCard(rows = rows)
}
