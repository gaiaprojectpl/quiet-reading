package app.quietreading.feature.onboarding

import app.quietreading.data.BookSource
import app.quietreading.data.ReadingStatus
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.roundToInt

/** A book read from an export file, before it is saved. */
data class ImportedBook(
    val title: String,
    val author: String,
    val isbn: String?,
    val pageCount: Int?,
    val status: ReadingStatus,
    val dateFinished: Long?,
    val rating: Int?,
    val source: BookSource,
)

class LibraryCsvException(val reason: Reason) : Exception(reason.name) {
    enum class Reason { Unreadable, NotRecognised, Empty }
}

/**
 * Reads Goodreads ("My Books › Import and export") and StoryGraph ("Manage account › Export") CSV files.
 * The format is detected from the header, so either file works whichever row the reader tapped.
 */
object LibraryCsv {
    fun parse(bytes: ByteArray): List<ImportedBook> {
        var text = runCatching { bytes.toString(Charsets.UTF_8) }.getOrNull()
            ?: throw LibraryCsvException(LibraryCsvException.Reason.Unreadable)
        if (text.startsWith("﻿")) text = text.substring(1)
        val rows = Csv.rows(text)
        val header = rows.firstOrNull() ?: throw LibraryCsvException(LibraryCsvException.Reason.Empty)
        val columns = mutableMapOf<String, Int>()
        header.forEachIndexed { i, name -> columns.putIfAbsent(name.trim(), i) }

        val books = when {
            "Exclusive Shelf" in columns && "Title" in columns -> rows.drop(1).mapNotNull { goodreads(it, columns) }
            "Read Status" in columns && "Title" in columns -> rows.drop(1).mapNotNull { storyGraph(it, columns) }
            else -> throw LibraryCsvException(LibraryCsvException.Reason.NotRecognised)
        }
        if (books.isEmpty()) throw LibraryCsvException(LibraryCsvException.Reason.Empty)
        return books
    }

    private fun goodreads(row: List<String>, c: Map<String, Int>): ImportedBook? {
        fun v(key: String) = value(row, c[key])
        val title = v("Title").ifEmpty { return null }
        return ImportedBook(
            title = title,
            author = v("Author"),
            isbn = cleanIsbn(v("ISBN13")) ?: cleanIsbn(v("ISBN")),
            pageCount = v("Number of Pages").toIntOrNull()?.takeIf { it > 0 },
            status = status(v("Exclusive Shelf")),
            dateFinished = date(v("Date Read")),
            rating = v("My Rating").toIntOrNull()?.takeIf { it > 0 },
            source = BookSource.Goodreads,
        )
    }

    private fun storyGraph(row: List<String>, c: Map<String, Int>): ImportedBook? {
        fun v(key: String) = value(row, c[key])
        val title = v("Title").ifEmpty { return null }
        return ImportedBook(
            title = title,
            author = v("Authors"),
            isbn = cleanIsbn(v("ISBN/UID")),
            pageCount = null,
            status = status(v("Read Status")),
            dateFinished = date(v("Last Date Read")),
            rating = v("Star Rating").toDoubleOrNull()?.roundToInt()?.takeIf { it > 0 },
            source = BookSource.StoryGraph,
        )
    }

    private fun value(row: List<String>, index: Int?) = if (index != null && index < row.size) row[index].trim() else ""

    private fun status(raw: String) = when (raw.lowercase()) {
        "currently-reading" -> ReadingStatus.Reading
        "read" -> ReadingStatus.Read
        "did-not-finish" -> ReadingStatus.Stopped
        else -> ReadingStatus.ToRead
    }

    /** Goodreads writes ISBNs as ="9780…". Keep digits (and a final X) only. */
    private fun cleanIsbn(raw: String): String? {
        val digits = raw.uppercase().filter { it.isDigit() || it == 'X' }
        return digits.takeIf { it.length == 10 || it.length == 13 }
    }

    private fun date(raw: String): Long? {
        if (raw.isEmpty()) return null
        for (format in listOf("yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyy")) {
            val f = SimpleDateFormat(format, Locale.US).apply { isLenient = false }
            runCatching { f.parse(raw) }.getOrNull()?.let { return it.time }
        }
        return null
    }
}

/** Minimal RFC 4180 CSV reader (quoted fields, escaped quotes, CRLF or LF). */
object Csv {
    fun rows(text: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < text.length) {
            val ch = text[i]
            if (inQuotes) {
                if (ch == '"') {
                    if (i + 1 < text.length && text[i + 1] == '"') { field.append('"'); i++ } else inQuotes = false
                } else field.append(ch)
            } else when (ch) {
                '"' -> inQuotes = true
                ',' -> { row.add(field.toString()); field.clear() }
                '\r' -> {}
                '\n' -> {
                    row.add(field.toString()); field.clear()
                    if (!(row.size == 1 && row[0].isEmpty())) rows.add(row)
                    row = mutableListOf()
                }
                else -> field.append(ch)
            }
            i++
        }
        if (field.isNotEmpty() || row.isNotEmpty()) { row.add(field.toString()); rows.add(row) }
        return rows
    }
}
