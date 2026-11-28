package app.quietreading.feature.stats

import android.graphics.Bitmap
import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Color
import app.quietreading.R
import app.quietreading.data.Book
import app.quietreading.data.ReadingStatus
import app.quietreading.data.SessionEntity
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.MonthDay
import java.time.YearMonth
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Flow 8 / 8b · Everything the Stats screens show, worked out from the books on this phone.
 * Pages read per day come from progress updates (sessions); finished books count on their finish date.
 */
class ReadingStats(val books: List<Book>, val now: LocalDateTime = LocalDateTime.now(), val zone: ZoneId = ZoneId.systemDefault()) {
    val today: LocalDate get() = now.toLocalDate()
    val currentYear: Int get() = now.year
    val firstDayOfWeek: DayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek

    fun date(ms: Long): LocalDateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(ms), zone)
    fun day(ms: Long): LocalDate = date(ms).toLocalDate()

    // Raw material

    val finished: List<Book> = books.filter { it.status == ReadingStatus.Read && it.dateFinished != null }
    val sessions: List<SessionEntity> = books.flatMap { it.sessions }
    val hasAnyData: Boolean get() = finished.isNotEmpty() || sessions.isNotEmpty()

    fun finishedDate(b: Book): LocalDate = day(b.dateFinished!!)

    fun finished(year: Int): List<Book> = finished.filter { finishedDate(it).year == year }.sortedBy { it.dateFinished }

    /** Years that have something to show, newest first (always includes this year). */
    val years: List<Int> get() = (finished.map { finishedDate(it).year } + currentYear).toSet().sortedDescending()

    /** Pages read per day. A finished book with no updates still marks the day it was finished. */
    val pagesByDay: Map<LocalDate, Int> by lazy {
        val result = mutableMapOf<LocalDate, Int>()
        for (s in sessions) result.merge(day(s.date), max(0, s.toPage - s.fromPage), Int::plus)
        for (b in finished) if (b.sessions.isEmpty()) result.merge(finishedDate(b), 0, Int::plus)
        result
    }

    // Goal

    data class Goal(val goal: Int, val done: Int, val perMonth: Double, val onPaceFor: Int) {
        val percent: Int get() = if (goal > 0) (done.toDouble() / goal * 100).roundToInt() else 0
        val left: Int get() = max(0, goal - done)
    }

    fun goal(target: Int, year: Int): Goal {
        val done = finished(year).size
        val isThisYear = year == currentYear
        val monthsElapsed = if (isThisYear) now.monthValue.toDouble() else 12.0
        val dayOfYear = if (isThisYear) now.dayOfYear.toDouble() else 365.0
        val daysInYear = today.lengthOfYear().toDouble()
        val pace = if (isThisYear) (done / max(dayOfYear, 1.0) * daysInYear).roundToInt() else done
        return Goal(target, done, done / monthsElapsed, pace)
    }

    // Week

    data class Day(val date: LocalDate, val pages: Int, val didRead: Boolean)

    /** The current week, first weekday first (Monday in most of Europe, Sunday in the US). */
    val thisWeek: List<Day> get() {
        val start = today.with(TemporalAdjusters.previousOrSame(firstDayOfWeek))
        return (0L until 7L).map { start.plusDays(it) }.map { Day(it, pagesByDay[it] ?: 0, pagesByDay.containsKey(it)) }
    }

    // Month

    enum class Level { Rest, Little, More, Lots }

    /** Days of the month containing [month], with how much was read. */
    fun days(month: YearMonth): List<Day> =
        (1..month.lengthOfMonth()).map { month.atDay(it) }.map { Day(it, pagesByDay[it] ?: 0, pagesByDay.containsKey(it)) }

    fun booksFinished(month: YearMonth): List<Book> = finished.filter { YearMonth.from(finishedDate(it)) == month }

    // Year

    /** Finished books per month (index 0 = January). */
    fun booksPerMonth(year: Int): List<Int> {
        val counts = IntArray(12)
        for (b in finished(year)) counts[finishedDate(b).monthValue - 1]++
        return counts.toList()
    }

    fun pages(year: Int): Int = finished(year).sumOf { it.pageCount ?: 0 }

    /** Authors finished this year that weren't finished in any earlier year. */
    fun newAuthors(year: Int): Int {
        val before = finished.filter { finishedDate(it).year < year }.map { it.author.lowercase() }.toSet()
        return (finished(year).map { it.author.lowercase() }.toSet() - before).size
    }

    fun favourite(year: Int): Book? =
        finished(year).filter { it.stars != null || it.entity.rating != null }.maxByOrNull { it.score }

    fun topMood(year: Int): String? =
        finished(year).flatMap { it.moods }.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key

    // Patterns (Plus)

    enum class Range(val title: String, val phrase: String) { Month("Month", "this month"), Year("Year", "this year"), All("All time", "so far") }

    fun finished(range: Range): List<Book> = when (range) {
        Range.Month -> finished.filter { YearMonth.from(finishedDate(it)) == YearMonth.from(today) }
        Range.Year -> finished(currentYear)
        Range.All -> finished
    }

    fun sessions(range: Range): List<SessionEntity> = when (range) {
        Range.Month -> sessions.filter { YearMonth.from(day(it.date)) == YearMonth.from(today) }
        Range.Year -> sessions.filter { day(it.date).year == currentYear }
        Range.All -> sessions
    }

    data class Share(val name: String, val value: Int)

    /** Moods tagged on finished books, most common first. */
    fun moods(range: Range): List<Share> =
        finished(range).flatMap { it.moods }.groupingBy { it }.eachCount().map { Share(it.key, it.value) }.sortedByDescending { it.value }

    /** Pages read by time of day. */
    fun timeOfDay(range: Range): List<Share> {
        val buckets = IntArray(4)
        for (s in sessions(range)) {
            val h = date(s.date).hour
            val i = when (h) { in 5..11 -> 0; in 12..16 -> 1; in 17..21 -> 2; else -> 3 }
            buckets[i] += max(1, s.toPage - s.fromPage)
        }
        return listOf("Morning", "Afternoon", "Evening", "Night").mapIndexed { i, n -> Share(n, buckets[i]) }
    }

    data class WeekPace(val start: LocalDate, val perDay: Double)

    /** Average pages a day for each of the last [weeks] weeks. */
    fun pace(weeks: Int = 12): List<WeekPace> {
        val thisWeek = today.with(TemporalAdjusters.previousOrSame(firstDayOfWeek))
        return (weeks - 1 downTo 0).map { back ->
            val start = thisWeek.minusWeeks(back.toLong())
            val pages = (0L until 7L).sumOf { pagesByDay[start.plusDays(it)] ?: 0 }
            WeekPace(start, pages / 7.0)
        }
    }

    /** How many books got each star value (1, 1½ … 5). */
    fun ratings(range: Range): List<Pair<Double, Int>> {
        val values = finished(range).mapNotNull { it.stars ?: it.entity.rating?.toDouble() }
        return (2..10).map { it / 2.0 }.map { s -> s to values.count { it == s } }
    }

    /** Running total of finished books per month (up to this month for the current year). */
    fun cumulative(year: Int): List<Int> {
        val last = if (year == currentYear) now.monthValue else 12
        var total = 0
        return booksPerMonth(year).take(last).map { total += it; total }
    }

    companion object {
        fun level(pages: Int?): Level = when {
            pages == null -> Level.Rest
            pages < 20 -> Level.Little
            pages < 50 -> Level.More
            else -> Level.Lots
        }
    }
}

/** Stars, falling back to the whole-star rating. */
val Book.score: Double get() = stars ?: entity.rating?.toDouble() ?: 0.0

// Stamps

/** "Collect, don't compete": stamps never expire and nothing resets. */
data class Stamp(
    val id: String,
    @param:DrawableRes val icon: Int,
    val name: String,
    /** How to get it (shown while it's locked) or what it was for. */
    val how: String,
    val earned: Boolean,
    /** Progress towards a countable stamp (7 of 10 books), null when it isn't countable. */
    val progress: Pair<Int, Int>? = null,
) {
    companion object {
        /** The next stamp to collect: the locked one closest to done. */
        fun next(all: List<Stamp>): Stamp? =
            all.filter { !it.earned && it.progress != null }.maxByOrNull { it.progress!!.first.toDouble() / it.progress.second }

        fun all(stats: ReadingStats, autumnDone: Boolean): List<Stamp> {
            val pagesRead = stats.pagesByDay.values.sum() + stats.finished.filter { it.sessions.isEmpty() }.sumOf { it.pageCount ?: 0 }
            fun daysAt(hours: (Int) -> Boolean) =
                stats.sessions.filter { hours(stats.date(it.date).hour) }.map { stats.day(it.date) }.toSet().size
            val lateNights = daysAt { it >= 23 || it < 4 }
            val mornings = daysAt { it in 4..7 }
            val moods = stats.books.flatMap { it.moods }.toSet().size
            val rated = stats.books.count { it.stars != null || it.entity.rating != null }
            val authors = stats.finished.map { it.author.lowercase() }.toSet().size
            val week = stats.thisWeek
            return listOf(
                Stamp("first", R.drawable.ic_qs_book, "First book", "Finish your first book.", stats.finished.isNotEmpty()),
                Stamp("pages1000", R.drawable.ic_qs_file, "1,000 pages", "Read 1,000 pages in all.", pagesRead >= 1000, min(pagesRead, 1000) to 1000),
                Stamp("nightowl", R.drawable.ic_qs_moon, "Night owl", "Read after 11 pm on 5 nights.", lateNights >= 5, min(lateNights, 5) to 5),
                Stamp("quote", R.drawable.ic_qs_quote, "First quote", "Save a line you loved.", stats.books.any { it.quotes.isNotEmpty() }),
                Stamp("long", R.drawable.ic_qs_flash, "500+ pages", "Finish a book with 500 pages or more.", stats.finished.any { (it.pageCount ?: 0) >= 500 }),
                Stamp("moods", R.drawable.ic_qs_heart, "5 moods", "Tag 5 different moods on your books.", moods >= 5, min(moods, 5) to 5),
                Stamp("autumn", R.drawable.ic_qs_calendar, "Autumn reads", "Finish the Cozy autumn challenge.", autumnDone),
                Stamp("reviews", R.drawable.ic_qs_star_empty, "10 reviews", "Rate 10 books.", rated >= 10, min(rated, 10) to 10),
                Stamp("earlybird", R.drawable.ic_qs_bell, "Early bird", "Read before 8 am on 5 mornings.", mornings >= 5, min(mornings, 5) to 5),
                Stamp("ten", R.drawable.ic_qs_library, "Ten books", "Finish 10 books.", stats.finished.size >= 10, min(stats.finished.size, 10) to 10),
                Stamp("week", R.drawable.ic_qs_check, "Seven days", "Read on every day of one week.", week.all { it.didRead }, week.count { it.didRead } to 7),
                Stamp("authors", R.drawable.ic_qs_bookmark, "Five authors", "Finish books by 5 different authors.", authors >= 5, min(authors, 5) to 5),
            )
        }
    }
}

/** Seasonal, opt-in challenge: "Cozy autumn · Read 3 books that felt cozy". Leaving loses nothing. */
class SeasonalChallenge private constructor(val start: LocalDate, val end: LocalDate, val books: List<Book>) {
    val goal = 3
    val done: Boolean get() = books.size >= goal

    companion object {
        const val JOINED_KEY = "challengeCozyAutumnJoined"

        /** Autumn this year (22 Sep – 21 Dec), or null outside autumn. */
        fun of(stats: ReadingStats): SeasonalChallenge? {
            val y = stats.currentYear
            val start = MonthDay.of(9, 22).atYear(y)
            val end = MonthDay.of(12, 21).atYear(y)
            if (stats.today.isBefore(start) || stats.today.isAfter(end)) return null
            val books = stats.finished.filter {
                val d = stats.finishedDate(it)
                !d.isBefore(start) && !d.isAfter(end) && "Cozy" in it.moods
            }
            return SeasonalChallenge(start, end, books)
        }
    }
}

/** Average colour of a cover, for its spine on the shelf. Cached per cover file. */
object SpineColor {
    private val cache = mutableMapOf<String, Color>()

    fun of(file: String?, bitmap: Bitmap?): Color? {
        if (file == null || bitmap == null) return null
        cache[file]?.let { return it }
        val small = Bitmap.createScaledBitmap(bitmap, 1, 1, true)
        val p = small.getPixel(0, 0)
        return Color(p).copy(alpha = 1f).also { cache[file] = it }
    }
}
