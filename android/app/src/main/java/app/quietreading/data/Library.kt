package app.quietreading.data

import android.content.Context
import kotlinx.coroutines.flow.Flow
import kotlin.math.max

/**
 * All reading data on this phone. Screens observe [books] and call these actions;
 * every action stamps `lastUpdated`, so the current book (= most recently updated Reading book) follows.
 */
class Library(context: Context) {
    val dao = AppDatabase.get(context).books()
    val covers = Covers(context)
    val books: Flow<List<Book>> = dao.library()

    suspend fun add(book: BookEntity): Long = dao.insert(book.copy(lastUpdated = System.currentTimeMillis()))

    suspend fun save(book: BookEntity) = dao.update(book.copy(lastUpdated = System.currentTimeMillis()))

    suspend fun delete(book: Book) {
        book.coverFile?.let { covers.delete(it) }
        dao.delete(book.entity)
    }

    suspend fun setStatus(book: Book, status: ReadingStatus) {
        val now = System.currentTimeMillis()
        save(book.entity.copy(
            status = status.raw,
            dateFinished = if (status == ReadingStatus.Read) (book.dateFinished ?: now) else null,
            currentPage = if (status == ReadingStatus.Read) (book.pageCount ?: book.currentPage) else book.currentPage,
        ))
    }

    /** Flow 3 › Update progress: a session from the old page to [page]; the book moves to Reading. */
    suspend fun updateProgress(book: Book, page: Int, minutes: Int? = null, note: String? = null, noteDrawing: String? = null) {
        val to = book.pageCount?.let { page.coerceIn(0, it) } ?: max(0, page)
        val entity = book.entity.copy(
            currentPage = to,
            status = if (book.status == ReadingStatus.Read) book.entity.status else ReadingStatus.Reading.raw,
            lastUpdated = System.currentTimeMillis(),
        )
        dao.addSession(entity, SessionEntity(bookId = book.id, fromPage = book.currentPage, toPage = to, minutes = minutes,
            note = note?.takeIf { it.isNotBlank() }, noteDrawing = noteDrawing))
    }

    /** Flow 3 › Finished moment. */
    suspend fun finish(book: Book, stars: Double?, moods: List<String>, note: String? = null) {
        val now = System.currentTimeMillis()
        val last = book.pageCount ?: book.currentPage
        if (last > book.currentPage || !note.isNullOrBlank()) {
            dao.insert(SessionEntity(bookId = book.id, fromPage = book.currentPage, toPage = last, note = note?.takeIf { it.isNotBlank() }))
        }
        save(book.entity.copy(status = ReadingStatus.Read.raw, currentPage = last, dateFinished = now,
            stars = stars, rating = stars?.let { kotlin.math.round(it).toInt() }, moods = moods.joinToString("|")))
    }

    suspend fun addQuote(quote: QuoteEntity): Long {
        dao.book(quote.bookId)?.let { save(it) }
        return dao.insert(quote)
    }
}

/** The current book = the Reading-shelf book updated most recently (agreed rule, Kaja 27 Nov). */
val List<Book>.reading: List<Book> get() = filter { it.status == ReadingStatus.Reading }.sortedByDescending { it.lastUpdated }
val List<Book>.current: Book? get() = reading.firstOrNull()
