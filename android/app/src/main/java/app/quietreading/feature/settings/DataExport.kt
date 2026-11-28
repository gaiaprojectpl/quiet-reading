package app.quietreading.feature.settings

import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import app.quietreading.data.Book
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Export (GDPR): books and quotes as CSV files the reader can save or share. */
object DataExport {
    private fun esc(s: String) = "\"" + s.replace("\"", "\"\"") + "\""

    fun files(context: Context, books: List<Book>): List<File> {
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        fun d(t: Long) = iso.format(Date(t))
        val csv = StringBuilder("Title,Author,ISBN13,Number of Pages,Shelf,Current Page,Date Added,Date Finished,My Rating,Moods\n")
        for (b in books) {
            csv.append(listOf(
                esc(b.title), esc(b.author), esc(b.isbn ?: ""), b.pageCount?.toString() ?: "", esc(b.status.shelfName),
                b.currentPage.toString(), d(b.dateAdded), b.dateFinished?.let(::d) ?: "",
                (b.stars ?: b.entity.rating?.toDouble())?.toString() ?: "", esc(b.moods.joinToString("; ")),
            ).joinToString(",")).append('\n')
        }
        val quotes = StringBuilder("Book,Author,Quote,Page,Feeling,Date\n")
        for (b in books) for (q in b.quotes) {
            quotes.append(listOf(esc(b.title), esc(b.author), esc(q.text), q.page?.toString() ?: "", esc(q.mood ?: ""), d(q.date)).joinToString(",")).append('\n')
        }
        val dir = File(context.cacheDir, "export").apply { mkdirs() }
        val booksFile = File(dir, "Quiet Reading – books.csv").apply { writeText(csv.toString()) }
        val quotesFile = File(dir, "Quiet Reading – quotes.csv").apply { writeText(quotes.toString()) }
        return listOf(booksFile, quotesFile)
    }

    /** The system share sheet with both files (save to Files, Drive, email…). */
    fun share(context: Context, books: List<Book>) {
        val uris = files(context, books).map { FileProvider.getUriForFile(context, "${context.packageName}.files", it) }
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "text/csv"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            clipData = ClipData.newRawUri("", uris.first()).apply { uris.drop(1).forEach { addItem(ClipData.Item(it)) } }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Export my data"))
    }
}
