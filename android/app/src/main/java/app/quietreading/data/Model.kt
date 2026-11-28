package app.quietreading.data

import androidx.annotation.DrawableRes
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.quietreading.R
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Where a book is on the reader's shelf (same raw values as iOS). */
enum class ReadingStatus(val raw: String, val shelfName: String, @param:DrawableRes val icon: Int) {
    Reading("reading", "Reading", R.drawable.ic_qs_bookmark),
    ToRead("toRead", "Want to read", R.drawable.ic_qs_heart),
    Read("read", "Finished", R.drawable.ic_qs_check),
    Stopped("stopped", "Didn’t finish", R.drawable.ic_qs_moon);

    /** Name used on a single book ("Reading now"). */
    val bookLabel: String get() = if (this == Reading) "Reading now" else shelfName

    companion object {
        /** Shelf order in the Library. */
        val shelves = listOf(Reading, ToRead, Read, Stopped)
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: ToRead
    }
}

/** Where a book came from. Kept so a later re-import can skip duplicates. */
enum class BookSource(val raw: String, val label: String) {
    Goodreads("goodreads", "Goodreads"),
    StoryGraph("storyGraph", "StoryGraph"),
    Manual("manual", "Added on this phone");

    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Manual }
}

/** One book on the reader's shelf, stored on this phone with Room. Times are epoch milliseconds. */
@Entity(tableName = "books")
data class BookEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val author: String,
    val isbn: String? = null,
    val pageCount: Int? = null,
    val currentPage: Int = 0,
    val status: String = ReadingStatus.ToRead.raw,
    val source: String = BookSource.Manual.raw,
    val rating: Int? = null,
    val dateAdded: Long = System.currentTimeMillis(),
    val dateFinished: Long? = null,
    val lastUpdated: Long = System.currentTimeMillis(),
    /** Cover JPEG file name in filesDir/covers (null = placeholder until a cover is found). */
    val coverFile: String? = null,
    /** 0.5–5 in half stars, set at the Finished moment. */
    val stars: Double? = null,
    /** "How did it feel?" chips chosen at the Finished moment, joined with "|". */
    val moods: String = "",
)

/** One progress update: from page → to page, optionally how long and a note. */
@Entity(
    tableName = "sessions",
    foreignKeys = [ForeignKey(entity = BookEntity::class, parentColumns = ["id"], childColumns = ["bookId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("bookId")],
)
data class SessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val bookId: Long,
    val date: Long = System.currentTimeMillis(),
    val fromPage: Int,
    val toPage: Int,
    val minutes: Int? = null,
    val note: String? = null,
    /** Handwritten note (stylus strokes, PNG file name); `note` keeps the recognised text. */
    val noteDrawing: String? = null,
)

/** A line worth keeping (Flow 9). Read from a page photo on the phone, or typed. */
@Entity(
    tableName = "quotes",
    foreignKeys = [ForeignKey(entity = BookEntity::class, parentColumns = ["id"], childColumns = ["bookId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("bookId")],
)
data class QuoteEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val bookId: Long,
    val text: String,
    val page: Int? = null,
    val mood: String? = null,
    val showOnWidget: Boolean = false,
    val fromPhoto: Boolean = false,
    val date: Long = System.currentTimeMillis(),
    val drawing: String? = null,
)

/** A book with its sessions and quotes – what screens work with. */
data class Book(
    val entity: BookEntity,
    val sessions: List<SessionEntity> = emptyList(),
    val quotes: List<QuoteEntity> = emptyList(),
) {
    val id get() = entity.id
    val title get() = entity.title
    val author get() = entity.author
    val isbn get() = entity.isbn
    val pageCount get() = entity.pageCount
    val currentPage get() = entity.currentPage
    val status get() = ReadingStatus.of(entity.status)
    val source get() = BookSource.of(entity.source)
    val stars get() = entity.stars
    val moods: List<String> get() = entity.moods.split("|").filter { it.isNotBlank() }
    val lastUpdated get() = entity.lastUpdated
    val dateAdded get() = entity.dateAdded
    val dateFinished get() = entity.dateFinished
    val coverFile get() = entity.coverFile

    /** 0…1, or null when the page count is unknown. */
    val progress: Float?
        get() = pageCount?.takeIf { it > 0 }?.let { min(1f, currentPage.toFloat() / it) }

    /** Average minutes per page: from timed sessions when there are any, otherwise a typical adult pace. */
    val minutesPerPage: Double
        get() {
            val timed = sessions.filter { (it.minutes ?: 0) > 0 && it.toPage > it.fromPage }
            val pages = timed.sumOf { it.toPage - it.fromPage }
            val minutes = timed.sumOf { it.minutes ?: 0 }
            return if (pages > 0) minutes.toDouble() / pages else 1.2
        }

    /** Estimated minutes left, null when the page count is unknown. */
    fun minutesLeft(fromPage: Int? = null): Int? {
        val total = pageCount ?: return null
        val left = max(0, total - (fromPage ?: currentPage))
        return (left * minutesPerPage).roundToInt()
    }

    /** When reading started: the first progress update, otherwise when it was added. */
    val startedDate: Long get() = sessions.minOfOrNull { it.date } ?: dateAdded

    /** Used to skip books that are already on the shelf. */
    val matchKey: String get() = matchKey(title, author, isbn)

    companion object {
        fun matchKey(title: String, author: String, isbn: String?) =
            if (!isbn.isNullOrEmpty()) "isbn:$isbn" else "t:${title.lowercase()}|${author.lowercase()}"
    }
}

/** "About 3 h 20 min left" */
object ReadingTime {
    fun left(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        val text = if (h > 0) (if (m > 0) "$h h $m min" else "$h h") else "${max(m, 1)} min"
        return "About $text left"
    }
}
