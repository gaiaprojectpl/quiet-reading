package app.quietreading.widget

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import app.quietreading.MainActivity
import app.quietreading.QuietReadingApplication
import app.quietreading.data.Book
import app.quietreading.data.Keys
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.ThemeId
import app.quietreading.feature.stats.ReadingStats
import kotlinx.coroutines.flow.first
import java.time.LocalDate
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * What the widgets show. On Android the widget runs in the app's own process, so it reads the
 * books and settings directly (no snapshot file like iOS). The app calls [Widgets.refresh] after every change.
 */
data class WidgetBook(
    val id: Long,
    val title: String,
    val author: String,
    val currentPage: Int,
    val pageCount: Int?,
    val minutesLeft: Int?,
    val cover: Bitmap?,
    /** The cover's own colour, deepened until white text reads at 6:1 (Colourful · Cover tone). */
    val coverTone: Int?,
) {
    val progress: Float? get() = pageCount?.takeIf { it > 0 }?.let { min(1f, currentPage.toFloat() / it) }
}

data class WidgetQuote(val text: String, val book: String, val page: Int?)

data class WidgetSnapshot(
    val current: WidgetBook?,
    val upNext: List<WidgetBook>,
    val quotes: List<WidgetQuote>,
    val goal: Int,
    val finishedThisYear: Int,
    val year: Int,
    /** Already resolved: High contrast > Night (dark mode) > chosen (Plus themes need Plus). */
    val theme: ThemeId,
    val isPlus: Boolean,
    val weekPages: List<Int>,
    val weekDays: List<LocalDate>,
)

object Widgets {
    suspend fun snapshot(context: Context): WidgetSnapshot {
        val env = (context.applicationContext as QuietReadingApplication).env
        val books = env.library.books.first()
        val prefs = env.prefs
        val isPlus = prefs.get(Keys.plusUnlocked, false)
        val chosen = ThemeId.entries.firstOrNull { it.name == prefs.get(Keys.theme, ThemeId.PeachSage.name) } ?: ThemeId.PeachSage
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val contrast = Build.VERSION.SDK_INT >= 34 && (context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).contrast >= 0.5f
        val theme = when {
            prefs.get(Keys.forceHighContrast, false) || contrast -> ThemeId.HighContrast
            night -> ThemeId.Night
            chosen.requiresPlus && !isPlus -> ThemeId.PeachSage
            else -> chosen
        }
        val reading = books.filter { it.status == ReadingStatus.Reading }.sortedByDescending { it.lastUpdated }
        val upNext = books.filter { it.status == ReadingStatus.ToRead }.sortedByDescending { it.lastUpdated }.take(3)
        val stats = ReadingStats(books)
        val allQuotes = books.flatMap { b -> b.quotes.map { it to b } }.sortedByDescending { it.first.date }
        val chosenQuotes = allQuotes.filter { it.first.showOnWidget }.ifEmpty { allQuotes }.take(10)
        val week = stats.thisWeek
        return WidgetSnapshot(
            current = reading.firstOrNull()?.let { item(env.covers.dir.path, it) },
            upNext = upNext.map { item(env.covers.dir.path, it) },
            quotes = chosenQuotes.map { (q, b) -> WidgetQuote(q.text, b.title, q.page) },
            goal = prefs.get(Keys.goal, 0),
            finishedThisYear = stats.finished(stats.currentYear).size,
            year = stats.currentYear,
            theme = theme,
            isPlus = isPlus,
            weekPages = week.map { it.pages },
            weekDays = week.map { it.date },
        )
    }

    private fun item(coverDir: String, b: Book): WidgetBook {
        val cover = b.coverFile?.let { smallCover("$coverDir/$it") }
        return WidgetBook(b.id, b.title, b.author, b.currentPage, b.pageCount, b.minutesLeft(), cover, cover?.let(::coverTone))
    }

    /** Widgets have a tight memory budget: covers are scaled to 240 px wide. */
    private fun smallCover(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0) return null
        val opts = BitmapFactory.Options().apply { inSampleSize = max(1, bounds.outWidth / 240) }
        val raw = BitmapFactory.decodeFile(path, opts) ?: return null
        return if (raw.width > 240) Bitmap.createScaledBitmap(raw, 240, raw.height * 240 / raw.width, true) else raw
    }

    /** Average colour of the cover, deepened until white text reaches 6:1 on it. */
    fun coverTone(bitmap: Bitmap): Int {
        val one = Bitmap.createScaledBitmap(bitmap, 1, 1, true).getPixel(0, 0)
        var r = ((one shr 16) and 0xFF) / 255.0
        var g = ((one shr 8) and 0xFF) / 255.0
        var b = (one and 0xFF) / 255.0
        fun lum(c: Double) = if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
        fun contrast() = 1.05 / (0.2126 * lum(r) + 0.7152 * lum(g) + 0.0722 * lum(b) + 0.05)
        while (contrast() < 6) { r *= 0.94; g *= 0.94; b *= 0.94 }
        return (0xFF shl 24) or ((r * 255).toInt() shl 16) or ((g * 255).toInt() shl 8) or (b * 255).toInt()
    }

    /** Opens the app at a quietreading:// link (book, add, stats, plus, update/<id>). */
    fun open(context: Context, link: String): Intent =
        Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW).setData(Uri.parse(link))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    /** Redraw every widget (books, goal, theme or Plus changed). */
    suspend fun refresh(context: Context) {
        ReadingNowWidget().updateAll(context)
        GoalWidget().updateAll(context)
        StyledReadingWidget().updateAll(context)
        ThisWeekWidget().updateAll(context)
        QuoteWidget().updateAll(context)
    }

    // Per-widget style (Plus): chosen when the widget is added, changeable by editing the widget.
    private fun stylePrefs(context: Context) = context.getSharedPreferences("widget_styles", Context.MODE_PRIVATE)

    fun style(context: Context, appWidgetId: Int): String? = stylePrefs(context).getString("style_$appWidgetId", null)
    fun setStyle(context: Context, appWidgetId: Int, style: String) = stylePrefs(context).edit().putString("style_$appWidgetId", style).apply()

    suspend fun styleFor(context: Context, glanceId: androidx.glance.GlanceId): String? =
        runCatching { style(context, GlanceAppWidgetManager(context).getAppWidgetId(glanceId)) }.getOrNull()
}

object WidgetText {
    fun timeLeft(minutes: Int?): String? {
        if (minutes == null || minutes <= 0) return null
        val h = minutes / 60
        val m = minutes % 60
        return when { h == 0 -> "$m min left"; m == 0 -> "$h h left"; else -> "$h h $m min left" }
    }

    fun percent(v: Float?): String? = v?.let { "${(it * 100).toInt()}%" }

    /** "Reading: Anne of Green Gables by L. M. Montgomery, 46%, page 142 of 310, 3 h left". */
    fun label(b: WidgetBook): String {
        val parts = mutableListOf("Reading: ${b.title}" + if (b.author.isNotEmpty()) " by ${b.author}" else "")
        percent(b.progress)?.let { parts += "$it percent".replace("% percent", " percent") }
        if (b.currentPage > 0) parts += b.pageCount?.let { "page ${b.currentPage} of $it" } ?: "page ${b.currentPage}"
        timeLeft(b.minutesLeft)?.let { parts += it }
        return parts.joinToString(", ")
    }

    fun pageLine(b: WidgetBook): String =
        if (b.currentPage <= 0) b.pageCount?.let { "$it pages" } ?: "Not started"
        else listOfNotNull("p. ${b.currentPage}", percent(b.progress)).joinToString(" · ")

    fun detail(b: WidgetBook, pageFirst: Boolean): String {
        val page = if (b.currentPage > 0) "p. ${b.currentPage}" else null
        val left = timeLeft(b.minutesLeft)
        return (if (pageFirst) listOf(page, left) else listOf(percent(b.progress), left ?: page)).filterNotNull().joinToString(" · ")
    }
}
