package app.quietreading.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Book
import app.quietreading.data.ReadingStatus
import app.quietreading.data.ReadingTime
import app.quietreading.data.current
import app.quietreading.data.reading
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsCard
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.TabScreen
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import app.quietreading.feature.book.BookRoutes
import app.quietreading.feature.book.rememberAllBooks
import app.quietreading.feature.progress.gentleAppear
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

fun NavGraphBuilder.homeGraph(nav: AppNav) {
    composable(Routes.HOME) { HomeScreen(nav) }
}

/**
 * Flow 1 › Step 5 · Home: today's date, the book being read now (the Reading book updated most recently),
 * other books in progress, and what's up next. No Update / Finished here (Kaja, 27 Nov): tap the book.
 */
@Composable
fun HomeScreen(nav: AppNav) {
    DebugSeed()
    val books = rememberAllBooks() ?: return
    val c = QsTheme.colors
    if (books.isEmpty()) {
        TabScreen("Home") {
            EmptyState(R.drawable.ic_qs_book, "Your shelf is ready", "Add the book you’re reading now. It takes a few seconds.")
            QsButton("Add a book", nav.showAddSheet)
            QsButton("Import from Goodreads or StoryGraph", nav::openImport, kind = QsButtonKind.Text)
        }
        return
    }
    val current = books.current
    val alsoReading = books.reading.drop(1)
    val upNext = books.filter { it.status == ReadingStatus.ToRead }.sortedByDescending { it.lastUpdated }.take(10)

    TabScreen("Home", header = {
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s20)) {
            Text(
                LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.getDefault())).uppercase(),
                style = QsType.caption.semibold().copy(letterSpacing = 0.72.sp), color = c.ink2,
            )
            Text("Reading now", style = QsTheme.headline(32), color = c.ink, modifier = Modifier.semantics { heading() })
        }
    }) {
        if (current != null) {
            CurrentBookCard(current) { nav.openBook(current.id) }
        } else {
            NothingInProgress(hasWantToRead = upNext.isNotEmpty(), onAdd = nav.showAddSheet) {
                nav.controller.navigate(BookRoutes.WHAT_NEXT)
            }
        }
        if (alsoReading.isNotEmpty()) {
            Text("Also reading", style = QsTheme.headline(20), color = c.ink, modifier = Modifier.semantics { heading() })
            QsListCard(rows = alsoReading.map { b -> @Composable { AlsoReadingRow(b) { nav.openBook(b.id) } } })
        }
        if (upNext.isNotEmpty()) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Up next", style = QsTheme.headline(20), color = c.ink, modifier = Modifier.weight(1f).semantics { heading() })
                Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(label = "See all") { nav.openLibrary(ReadingStatus.ToRead) }
                    .padding(horizontal = QsSpace.s4), contentAlignment = Alignment.Center) {
                    Text("See all", style = QsType.subheadline.medium(), color = c.accentInk)
                }
            }
            // Edge to edge of the screen, with the 20 dp margin inside the scroll.
            LazyRow(
                Modifier.fillMaxWidth().padding(horizontal = 0.dp).layoutEdgeToEdge(),
                contentPadding = PaddingValues(horizontal = QsSpace.s20, vertical = QsSpace.s4),
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
            ) {
                items(upNext, key = { it.id }) { book -> UpNextTile(book) { nav.openBook(book.id) } }
            }
        }
    }
}

/** Cancels the screen's 20 dp side margin so the row scrolls edge to edge. */
private fun Modifier.layoutEdgeToEdge(): Modifier = this.then(
    Modifier.layout { measurable, constraints ->
        val extra = (QsSpace.s20 * 2).roundToPx()
        val placeable = measurable.measure(constraints.copy(maxWidth = constraints.maxWidth + extra, minWidth = constraints.minWidth + extra))
        layout(constraints.maxWidth, placeable.height) { placeable.place(-extra / 2, 0) }
    },
)

private val tileWidth = 105.dp

@Composable
private fun UpNextTile(book: Book, onClick: () -> Unit) {
    val c = QsTheme.colors
    Column(
        Modifier.width(tileWidth).pressable(label = "Open the book", onClick = onClick)
            .clearAndSetSemantics { contentDescription = "${book.title}, ${book.author}"; onClick("Open the book") { onClick(); true } },
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        BookCover(book.coverFile, book.title, width = tileWidth)
        Text(book.title, style = QsType.footnote.medium(), color = c.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        val p = book.progress
        if (p != null && book.currentPage > 0) QsProgressBar(p, small = true)
    }
}

/** Figma: Home › Current book card. The whole card opens the book. */
@Composable
private fun CurrentBookCard(book: Book, onOpen: () -> Unit) {
    val c = QsTheme.colors
    QsCard(Modifier.pressable(label = "Open the book", onClick = onOpen).semantics(mergeDescendants = true) {}) {
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            BookCover(book.coverFile, book.title, width = 96.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                Text("READING NOW", style = QsType.caption2.semibold().copy(letterSpacing = 0.66.sp), color = c.ink2)
                Text(book.title, style = QsTheme.headline(21), color = c.ink)
                if (book.author.isNotBlank()) Text(book.author, style = QsType.subheadline, color = c.ink2)
                val pages = book.pageCount
                val p = book.progress
                val left = book.minutesLeft()?.takeIf { it > 0 }
                if (book.currentPage == 0 && pages != null) {
                    Text("$pages pages", style = QsType.footnote, color = c.ink2)
                    left?.let { Text(ReadingTime.left(it), style = QsType.footnote, color = c.ink2) }
                } else if (p != null && pages != null) {
                    QsProgressBar(p)
                    Text("p. ${book.currentPage} of $pages · ${(p * 100).roundToInt()}%", style = QsType.footnote, color = c.ink2)
                    left?.let { Text(ReadingTime.left(it), style = QsType.footnote, color = c.ink2) }
                } else if (book.currentPage > 0) {
                    Text("p. ${book.currentPage}", style = QsType.footnote, color = c.ink2)
                }
            }
        }
    }
}

/** One more book in progress: cover, title, progress. Tap for details (Update / Finished live there). */
@Composable
private fun AlsoReadingRow(book: Book, onOpen: () -> Unit) {
    val c = QsTheme.colors
    val line = when {
        book.pageCount != null && book.currentPage > 0 -> "p. ${book.currentPage} of ${book.pageCount}"
        book.currentPage > 0 -> "p. ${book.currentPage}"
        else -> "Not started"
    }
    Row(
        Modifier.fillMaxWidth().pressable(label = "Open the book", onClick = onOpen).semantics(mergeDescendants = true) {}.padding(QsSpace.s12),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        BookCover(book.coverFile, book.title, width = QsSpace.s40)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
            Text(book.title, style = QsTheme.headline(17), color = c.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            val p = book.progress
            if (p != null && book.currentPage > 0) QsProgressBar(p, small = true)
            Text(line, style = QsType.footnote, color = c.ink2)
        }
        QsIcon(R.drawable.ic_qs_chevron, tint = c.ink2, size = QsSize.iconS)
    }
}

/** Flow 10 › A4 · Home · nothing in progress: no streak warning, no pressure. */
@Composable
private fun NothingInProgress(hasWantToRead: Boolean, onAdd: () -> Unit, onChoose: () -> Unit) {
    val c = QsTheme.colors
    Column(Modifier.gentleAppear(), verticalArrangement = Arrangement.spacedBy(QsSpace.s20)) {
        QsCard {
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
                Box(Modifier.size(QsSize.coverM, QsSize.coverM * 1.5f).background(c.disabledBg, RoundedCornerShape(QsTheme.shapes.cover)))
                Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                    Text("No book yet", style = QsTheme.headline(20), color = c.ink)
                    Text("Add one by photographing its cover.", style = QsType.subheadline, color = c.ink2)
                }
            }
            QsButton("Add a book", onAdd)
        }
        if (hasWantToRead) {
            Text("You finished every book you were reading. Pick the next one from Want to read, or let it wait.", style = QsType.subheadline, color = c.ink2)
            QsButton("Choose from Want to read", onChoose, kind = QsButtonKind.Secondary)
        }
    }
}
