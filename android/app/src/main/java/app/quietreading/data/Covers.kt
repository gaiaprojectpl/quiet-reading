package app.quietreading.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/** Cover images as small JPEG files in filesDir/covers (the widgets read the same folder). */
class Covers(context: Context) {
    val dir = File(context.filesDir, "covers").apply { mkdirs() }

    fun file(name: String) = File(dir, name)

    /** Saves [bytes] (any image) as a JPEG at most 600 px tall; returns the file name. */
    suspend fun save(bytes: ByteArray): String? = withContext(Dispatchers.IO) {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return@withContext null
        save(bitmap)
    }

    suspend fun save(bitmap: Bitmap): String? = withContext(Dispatchers.IO) {
        val scaled = if (bitmap.height > 600) Bitmap.createScaledBitmap(bitmap, bitmap.width * 600 / bitmap.height, 600, true) else bitmap
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
        val name = "${UUID.randomUUID()}.jpg"
        File(dir, name).writeBytes(out.toByteArray())
        name
    }

    fun delete(name: String) { File(dir, name).delete() }

    /**
     * Covers fill in by themselves (20 at a time): by ISBN, otherwise the best title + author match
     * (Goodreads exports often have no ISBN).
     */
    suspend fun backfill(library: Library, books: List<Book>) {
        for (book in books.filter { it.coverFile == null }.take(20)) {
            val bytes = BookSearch.coverBytes(book.isbn) ?: titleCover(book) ?: continue
            val name = save(bytes) ?: continue
            library.dao.book(book.id)?.let { library.dao.update(it.copy(coverFile = name)) }
        }
    }

    private suspend fun titleCover(book: Book): ByteArray? {
        val key = { s: String -> s.lowercase().filter { it.isLetterOrDigit() } }
        val matches = BookSearch.search("${book.title} ${book.author}").filter {
            key(it.title).startsWith(key(book.title).take(12)) && it.coverUrl != null
        }
        // English edition first (the app is English); other languages only as a last resort.
        val match = matches.firstOrNull { it.detail == "English edition" } ?: matches.firstOrNull { it.detail == null } ?: return null
        return BookSearch.download(match.coverUrl!!)
    }
}
