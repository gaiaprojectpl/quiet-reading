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

    /** Covers fill in by themselves: books with an ISBN and no cover yet (20 at a time). */
    suspend fun backfill(library: Library, books: List<Book>) {
        for (book in books.filter { it.coverFile == null && it.isbn != null }.take(20)) {
            val bytes = BookSearch.coverBytes(book.isbn) ?: continue
            val name = save(bytes) ?: continue
            library.dao.book(book.id)?.let { library.dao.update(it.copy(coverFile = name)) }
        }
    }
}
