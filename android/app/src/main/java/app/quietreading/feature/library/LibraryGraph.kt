package app.quietreading.feature.library

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.ChipFlow
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.ScreenHeader
import app.quietreading.designsystem.components.TabScreen
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import app.quietreading.feature.add.QsTextField
import kotlinx.coroutines.launch
import java.util.Calendar

fun NavGraphBuilder.libraryGraph(nav: AppNav) {
    composable(Routes.LIBRARY) { LibraryScreen(nav) }
}

/** Flow 7 › Step 1 · Library: shelves with counts, a 3-column grid, search, sort & filter. */
@Composable
fun LibraryScreen(nav: AppNav) {
    val books = LocalApp.current.library.books.collectAsState(initial = null).value ?: return
    if (books.isEmpty()) { EmptyLibrary(nav); return }

    var shelfRaw by rememberSaveable { mutableStateOf(ReadingStatus.Reading.raw) }
    val shelf = ReadingStatus.of(shelfRaw)
    var picked by rememberSaveable { mutableStateOf(false) }
    var searching by rememberSaveable { mutableStateOf(false) }
    var query by rememberSaveable { mutableStateOf("") }
    var filter by remember { mutableStateOf(LibraryFilter()) }
    var showFilter by remember { mutableStateOf(false) }
    fun count(s: ReadingStatus) = books.count { it.status == s }

    // Opens a specific shelf (Home › Up next › See all → Want to read); otherwise the first shelf with books.
    LaunchedEffect(nav.requestedShelf, books.isNotEmpty()) {
        val wanted = nav.requestedShelf
        if (wanted != null) {
            shelfRaw = wanted.raw; picked = true; nav.requestedShelf = null
        } else if (!picked) {
            picked = true
            if (count(shelf) == 0) ReadingStatus.shelves.firstOrNull { count(it) > 0 }?.let { shelfRaw = it.raw }
        }
    }

    val q = query.trim().lowercase()
    val visible = filter.apply(books.filter { it.status == shelf })
        .filter { q.isEmpty() || it.title.lowercase().contains(q) || it.author.lowercase().contains(q) }

    TabScreen("Library", header = {
        ScreenHeader("Library") {
            QsIconButton(R.drawable.ic_qs_search, if (searching) "Close search" else "Search") {
                searching = !searching
                if (!searching) query = ""
            }
            QsIconButton(R.drawable.ic_qs_sort, "Sort and filter") { showFilter = true }
        }
    }) {
        if (searching) {
            QsTextField(query, { query = it }, "Title or author", label = "Search", leadingIcon = R.drawable.ic_qs_search,
                imeAction = ImeAction.Search, capitalization = KeyboardCapitalization.None)
        }
        ShelfChips(shelf, ::count) { shelfRaw = it.raw }
        val inMs = if (QsTheme.reduceMotion) 0 else QsMotion.base
        val outMs = if (QsTheme.reduceMotion) 0 else QsMotion.fast
        AnimatedContent(
            targetState = Triple(shelf, filter, visible.map { it.id }),
            transitionSpec = { fadeIn(tween(inMs)) togetherWith fadeOut(tween(outMs)) },
            label = "shelf",
        ) { _ ->
            when {
                visible.isEmpty() && q.isNotEmpty() -> NoResults(query) { nav.showAddSheet() }
                visible.isEmpty() -> EmptyShelf(shelf)
                else -> Grid(visible) { nav.openBook(it.id) }
            }
        }
    }
    if (showFilter) SortFilterSheet(filter, books, shelf, onApply = { filter = it; showFilter = false }, onDismiss = { showFilter = false })
}

/** Shelf chips, edge to edge, keeping the selected shelf in view. */
@Composable
private fun ShelfChips(shelf: ReadingStatus, count: (ReadingStatus) -> Int, onSelect: (ReadingStatus) -> Unit) {
    val state = rememberLazyListState()
    val reduce = QsTheme.reduceMotion
    LaunchedEffect(shelf) {
        val i = ReadingStatus.shelves.indexOf(shelf)
        if (reduce) state.scrollToItem(i) else state.animateScrollToItem(i, -80)
    }
    // Break out of the 20 dp page margins so chips scroll to the screen edges.
    LazyRow(
        state = state,
        modifier = Modifier.layout { m, c ->
            val extra = QsSpace.s20.roundToPx() * 2
            val p = m.measure(c.copy(maxWidth = c.maxWidth + extra, minWidth = c.minWidth + extra))
            layout(c.maxWidth, p.height) { p.place(-extra / 2, 0) }
        },
        contentPadding = PaddingValues(horizontal = QsSpace.s20),
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        itemsIndexed(ReadingStatus.shelves) { _, s ->
            QsChip("${s.shelfName} ${count(s)}", selected = shelf == s) { onSelect(s) }
        }
    }
}

@Composable
private fun Grid(books: List<Book>, onOpen: (Book) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
        books.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                row.forEach { b -> LibraryTile(b, Modifier.weight(1f)) { onOpen(b) } }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** Figma: Books › Book grid cell. Cover, title, then progress (reading) or ★ rating. */
@Composable
private fun LibraryTile(book: Book, modifier: Modifier, onClick: () -> Unit) {
    val c = QsTheme.colors
    Column(
        modifier.pressable(label = "Open") { onClick() }
            .clearAndSetSemantics { contentDescription = "${book.title}, ${book.author}"; role = Role.Button },
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        BookCover(book.coverFile, book.title, width = null)
        Text(book.title, style = QsType.footnote.medium(), color = c.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        val progress = book.progress
        val stars = book.stars ?: book.entity.rating?.toDouble()
        if (book.status == ReadingStatus.Reading && progress != null && book.currentPage > 0) {
            QsProgressBar(progress, small = true)
        } else if (stars != null) {
            Text("★ ${formatStars(stars)}", style = QsType.caption, color = c.ink2)
        }
    }
}

private fun formatStars(v: Double) = if (v % 1.0 == 0.0) v.toInt().toString() else v.toString()

/** Flow 7 › No search results. */
@Composable
private fun NoResults(query: String, onAdd: () -> Unit) {
    val c = QsTheme.colors
    Column(Modifier.fillMaxWidth().padding(top = QsSpace.s40), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
        QsIcon(R.drawable.ic_qs_search, tint = c.ink, size = QsSpace.s40)
        Text("No books match “$query”", style = QsTheme.headline(22), color = c.ink, textAlign = TextAlign.Center)
        Text("Check the spelling, or add the book by photographing its cover.", style = QsType.subheadline, color = c.ink2, textAlign = TextAlign.Center)
        Spacer(Modifier.size(QsSpace.s4))
        QsButton("Add by photo", onAdd)
    }
}

/** Flow 7 › Empty shelf: three soft spines and a calm line. */
@Composable
private fun EmptyShelf(shelf: ReadingStatus) {
    val c = QsTheme.colors
    val message = when (shelf) {
        ReadingStatus.Reading -> "Books you’re reading show up here. Pick one from Want to read when you’re ready."
        ReadingStatus.ToRead -> "Books you’d like to read one day land here."
        ReadingStatus.Read -> "Finished books gather here, one by one."
        ReadingStatus.Stopped -> "Books you stop reading land here. No judgement, just a quiet shelf."
    }
    Column(
        Modifier.fillMaxWidth().padding(top = QsSpace.s40).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Row(Modifier.padding(vertical = QsSpace.s8).clearAndSetSemantics {}, verticalAlignment = Alignment.Bottom) {
            val shape = RoundedCornerShape(QsTheme.shapes.cover)
            Box(Modifier.size(64.dp, 96.dp).rotate(-7f).background(c.soft, shape))
            Box(Modifier.size(64.dp, 96.dp).background(c.soft2, shape))
            Box(Modifier.size(64.dp, 96.dp).rotate(7f).background(c.soft, shape))
        }
        Text("Nothing here, and that’s fine", style = QsTheme.headline(22), color = c.ink, textAlign = TextAlign.Center)
        Text(message, style = QsType.subheadline, color = c.ink2, textAlign = TextAlign.Center)
    }
}

/** Flow 10 › Library · empty: no books at all. Inline buttons (tab screen rule). */
@Composable
private fun EmptyLibrary(nav: AppNav) {
    TabScreen("Library") {
        EmptyState(R.drawable.ic_qs_library, "Your library starts here", "Add books by photo, title or barcode, or bring them over from Goodreads.")
        QsButton("Add a book", { nav.showAddSheet() })
        QsButton("Import a library", { nav.openImport() }, kind = QsButtonKind.Outline)
    }
}

// MARK: Sort & filter

enum class LibrarySort(val label: String) { Recent("Recently updated"), Title("Title"), Author("Author"), Rating("My rating") }

enum class FinishedIn {
    ThisYear, LastYear, Earlier;

    val label: String get() {
        val year = Calendar.getInstance().get(Calendar.YEAR)
        return when (this) { ThisYear -> "$year"; LastYear -> "${year - 1}"; Earlier -> "Earlier" }
    }

    fun contains(date: Long?): Boolean {
        date ?: return false
        val year = Calendar.getInstance().get(Calendar.YEAR)
        val y = Calendar.getInstance().apply { timeInMillis = date }.get(Calendar.YEAR)
        return when (this) { ThisYear -> y == year; LastYear -> y == year - 1; Earlier -> y < year - 1 }
    }
}

data class LibraryFilter(
    val sort: LibrarySort = LibrarySort.Recent,
    val moods: Set<String> = emptySet(),
    val finishedIn: Set<FinishedIn> = emptySet(),
) {
    fun apply(books: List<Book>): List<Book> = books
        .filter { moods.isEmpty() || it.moods.any { m -> m in moods } }
        .filter { b -> finishedIn.isEmpty() || finishedIn.any { it.contains(b.dateFinished) } }
        .let { list ->
            when (sort) {
                LibrarySort.Recent -> list.sortedByDescending { it.lastUpdated }
                LibrarySort.Title -> list.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.title })
                LibrarySort.Author -> list.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.author })
                LibrarySort.Rating -> list.sortedByDescending { it.stars ?: (it.entity.rating ?: 0).toDouble() }
            }
        }
}

/** Flow 7 › Sort & filter sheet. Changes apply with "Show N books". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SortFilterSheet(filter: LibraryFilter, books: List<Book>, shelf: ReadingStatus, onApply: (LibraryFilter) -> Unit, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    var draft by remember { mutableStateOf(filter) }
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val base = listOf("Cozy", "Slow", "Hopeful", "Dark", "Funny")
    val moodOptions = base + (books.flatMap { it.moods }.toSet() - base.toSet()).sorted()
    val resultCount = draft.apply(books.filter { it.status == shelf }).size

    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = state, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8),
                verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
            ) {
                Text("Sort & filter", style = QsTheme.headline(24), color = c.ink, modifier = Modifier.semantics { heading() })
                Section("Sort by") {
                    LibrarySort.entries.forEach { s -> QsChip(s.label, draft.sort == s) { draft = draft.copy(sort = s) } }
                }
                Section("Mood") {
                    moodOptions.forEach { m ->
                        QsChip(m, m in draft.moods) { draft = draft.copy(moods = if (m in draft.moods) draft.moods - m else draft.moods + m) }
                    }
                }
                Section("Finished in") {
                    FinishedIn.entries.forEach { f ->
                        QsChip(f.label, f in draft.finishedIn) { draft = draft.copy(finishedIn = if (f in draft.finishedIn) draft.finishedIn - f else draft.finishedIn + f) }
                    }
                }
            }
            Box(Modifier.fillMaxWidth().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s12, bottom = QsSpace.s24)) {
                QsButton(if (resultCount == 1) "Show 1 book" else "Show $resultCount books", {
                    scope.launch { state.hide() }.invokeOnCompletion { onApply(draft) }
                })
            }
        }
    }
}

@Composable
private fun Section(title: String, chips: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        Text(title.uppercase(), style = QsType.caption.semibold().copy(letterSpacing = 0.72.sp), color = QsTheme.colors.ink2,
            modifier = Modifier.semantics { heading() })
        ChipFlow { chips() }
    }
}
