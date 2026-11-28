package app.quietreading.feature.onboarding

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.quietreading.data.AppEnvironment
import app.quietreading.data.Book
import app.quietreading.data.BookEntity
import app.quietreading.data.BookSearch
import app.quietreading.data.BookSource
import app.quietreading.data.Keys
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.components.Notifier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * Runs one import: reads the file, saves the books, then looks up covers in the background.
 * App-wide (an object), so "Continue in the background" keeps it running; when it ends,
 * "Your library is ready" shows on whatever screen is open.
 */
object ImportSession {
    enum class Phase { Idle, Matching, Finished, Failed }

    var phase by mutableStateOf(Phase.Idle); private set
    var total by mutableIntStateOf(0); private set
    var done by mutableIntStateOf(0); private set
    var missingCovers by mutableIntStateOf(0); private set
    /** The last few covers found (file names), shown as thumbnails while matching. */
    var recentCovers by mutableStateOf<List<String>>(emptyList()); private set
    /** "Goodreads" / "StoryGraph", for "214 books from Goodreads". */
    var sourceName by mutableStateOf(""); private set
    private var startedMatching by mutableLongStateOf(0L)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null

    val fraction: Float get() = if (total == 0) 0f else done.toFloat() / total

    /** Rough time left, from the pace so far ("about a minute left"). */
    val timeLeftText: String?
        get() {
            if (phase != Phase.Matching || done <= 3) return null
            val perBook = (System.currentTimeMillis() - startedMatching) / 1000.0 / done
            val seconds = perBook * (total - done)
            return when {
                seconds < 45 -> "less than a minute left"
                seconds < 90 -> "about a minute left"
                else -> "about ${(seconds / 60).roundToInt()} minutes left"
            }
        }

    fun start(context: Context, uri: Uri, env: AppEnvironment, notifier: Notifier) {
        job?.cancel()
        total = 0; done = 0; missingCovers = 0; recentCovers = emptyList()
        phase = Phase.Matching
        job = scope.launch {
            val imported = withContext(Dispatchers.IO) {
                runCatching {
                    val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@runCatching null
                    LibraryCsv.parse(bytes)
                }.getOrNull()
            }
            if (imported == null) { phase = Phase.Failed; return@launch }

            val dao = env.library.dao
            val known = dao.allBooks().map { Book.matchKey(it.title, it.author, it.isbn) }.toMutableSet()
            val fresh = imported.filter { known.add(Book.matchKey(it.title, it.author, it.isbn)) }.map {
                BookEntity(
                    title = it.title, author = it.author, isbn = it.isbn, pageCount = it.pageCount,
                    currentPage = if (it.status == ReadingStatus.Read) (it.pageCount ?: 0) else 0,
                    status = it.status.raw, source = it.source.raw, rating = it.rating, dateFinished = it.dateFinished,
                )
            }
            val ids = dao.insertAll(fresh)
            total = fresh.size
            sourceName = if (imported.first().source == BookSource.StoryGraph) "StoryGraph" else "Goodreads"
            startedMatching = System.currentTimeMillis()
            if (fresh.isNotEmpty()) matchCovers(env, fresh.zip(ids).map { (b, id) -> b.copy(id = id) })
            env.prefs.set(Keys.lastImport, System.currentTimeMillis())
            env.prefs.set(Keys.lastImportSource, sourceName)
            phase = Phase.Finished
            if (total > 0) notifier.show("Your library is ready", if (total == 1) "1 book" else "$total books")
        }
    }

    fun reset() { if (phase != Phase.Matching) phase = Phase.Idle }

    private suspend fun matchCovers(env: AppEnvironment, books: List<BookEntity>) {
        // Four at a time keeps Open Library happy and the import quick.
        for (chunk in books.chunked(4)) {
            val results = coroutineScopeAsync(chunk.map { b -> suspend { BookSearch.coverBytes(b.isbn)?.let { env.covers.save(it) } } })
            chunk.zip(results).forEach { (book, file) ->
                if (file != null) {
                    env.library.dao.book(book.id)?.let { env.library.dao.update(it.copy(coverFile = file)) }
                    recentCovers = (recentCovers + file).takeLast(4)
                } else missingCovers++
                done++
            }
        }
    }

    private suspend fun <T> coroutineScopeAsync(blocks: List<suspend () -> T>): List<T> =
        kotlinx.coroutines.coroutineScope { blocks.map { async(Dispatchers.IO) { it() } }.awaitAll() }
}
