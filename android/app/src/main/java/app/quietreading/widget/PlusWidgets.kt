package app.quietreading.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import app.quietreading.R
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.WidgetStyleId
import app.quietreading.designsystem.colors
import java.time.format.TextStyle as DateTextStyle
import java.time.LocalDate
import java.util.Locale

// Plus widgets (Figma › Widgets Final): Soft (Blush, Lilac, Butter, Sage mist), Colourful (Cover tone, Sunset, Pop),
// Large Up next, Modern "This week", Quote. The style is chosen when the widget is added (WidgetStyleActivity).
// Without Plus they show one calm card that opens the Plus screen – no dark patterns.

/** Styles offered for "Reading now · Plus". "coverTone" is built from the current cover. */
val readingStyles = listOf("Blush", "Lilac", "Butter", "SageMist", "coverTone", "Sunset", "Pop")

@Composable
private fun PlusLocked(theme: ThemeId) {
    val p = WPalette.theme(theme.colors())
    WidgetRoot(p, "quietreading://plus") {
        Column(GlanceModifier.fillMaxSize().semantics { contentDescription = "A Plus widget. Tap to see Quiet Reading Plus." }) {
            Image(ImageProvider(R.drawable.ic_qs_crown), null, GlanceModifier.size(20.dp), colorFilter = ColorFilter.tint(p.accent.cp()))
            Spacer(GlanceModifier.defaultWeight())
            WText("A Plus widget", p.ink, 16.sp, serif = true)
            WText("Tap to see Quiet Reading Plus.", p.ink2, 11.sp, maxLines = 2)
        }
    }
}

@Composable
private fun UpdateLink(book: WidgetBook, content: @Composable () -> Unit) {
    val context = LocalContext.current
    Box(GlanceModifier.clickable(actionStartActivity(Widgets.open(context, "quietreading://update/${book.id}")))
        .semantics { contentDescription = "Update my page in ${book.title}" }) { content() }
}

@Composable
private fun Ribbon(p: WPalette) {
    Image(ImageProvider(ribbon(p.accent)), null, GlanceModifier.size(12.dp, 30.dp))
}

// MARK: Reading now · Plus (small, medium, large Up next)

class StyledReadingWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = Widgets.snapshot(context)
        val styleName = Widgets.styleFor(context, id) ?: "Blush"
        val style = WidgetStyleId.entries.firstOrNull { it.name == styleName }
        val p = style?.let { WPalette.style(it.palette, it.family) } ?: WPalette.coverTone(s.current?.coverTone, s.theme.colors().accent)
        provideContent {
            val book = s.current
            when {
                !s.isPlus -> PlusLocked(s.theme)
                book == null -> WidgetRoot(WPalette.theme(s.theme.colors()), "quietreading://add") { NothingInProgress(WPalette.theme(s.theme.colors()), true) }
                else -> WidgetRoot(p, "quietreading://book/${book.id}") {
                    val size = LocalSize.current
                    when {
                        size.height >= LARGE.height -> LargeUpNext(book, s.upNext, p)
                        size.width >= MEDIUM.width -> MediumStyled(book, p, styleName == "coverTone")
                        p.family == "soft" -> SmallSoft(book, p)
                        else -> SmallColourful(book, p)
                    }
                }
            }
        }
    }
}

class StyledReadingReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget = StyledReadingWidget() }

@Composable
private fun SmallSoft(book: WidgetBook, p: WPalette) {
    Column(GlanceModifier.fillMaxSize().semantics { contentDescription = WidgetText.label(book) }) {
        Row(GlanceModifier.fillMaxWidth()) {
            WCover(book, 34.dp, p)
            Spacer(GlanceModifier.defaultWeight())
            Ribbon(p)
        }
        Spacer(GlanceModifier.defaultWeight())
        WText(book.title, p.ink, 15.sp, serif = true, weight = FontWeight.Medium, maxLines = 2)
        book.progress?.let { Spacer(GlanceModifier.height(5.dp)); WProgress(it, p, 3.dp); Spacer(GlanceModifier.height(5.dp)) }
        WText(WidgetText.detail(book, pageFirst = false), p.ink2, 12.sp, serif = true, italic = true)
    }
}

@Composable
private fun SmallColourful(book: WidgetBook, p: WPalette) {
    Column(GlanceModifier.fillMaxSize().semantics { contentDescription = WidgetText.label(book) }) {
        Row(GlanceModifier.fillMaxWidth()) {
            WCover(book, 40.dp, p)
            Spacer(GlanceModifier.defaultWeight())
            WidgetText.percent(book.progress)?.let { WText(it, p.ink, 24.sp, serif = true, weight = FontWeight.Medium) }
        }
        Spacer(GlanceModifier.defaultWeight())
        WText(book.title, p.ink, 15.sp, serif = true, weight = FontWeight.Medium, maxLines = 2)
        book.progress?.let { Spacer(GlanceModifier.height(5.dp)); WProgress(it, p, 4.dp); Spacer(GlanceModifier.height(5.dp)) }
        WText(WidgetText.detail(book, pageFirst = true), p.ink2, 11.sp, weight = FontWeight.Medium)
    }
}

@Composable
private fun MediumStyled(book: WidgetBook, p: WPalette, tone: Boolean) {
    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        WCover(book, 72.dp, p)
        Spacer(GlanceModifier.width(16.dp))
        Column(GlanceModifier.defaultWeight().semantics { contentDescription = WidgetText.label(book) }) {
            Row(GlanceModifier.fillMaxWidth()) {
                WText(if (p.family == "soft") "currently reading" else "Reading now", p.ink2, 13.sp, GlanceModifier.defaultWeight(), serif = true, italic = true)
                if (p.family == "soft") Ribbon(p)
            }
            WText(book.title, p.ink, 18.sp, serif = true, weight = FontWeight.Medium, maxLines = 2)
            if (book.author.isNotEmpty()) WText(book.author, p.ink2, 12.sp)
            book.progress?.let { Spacer(GlanceModifier.height(8.dp)); WProgress(it, p, 3.dp); Spacer(GlanceModifier.height(8.dp)) }
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                val line = if (tone) listOfNotNull(WidgetText.percent(book.progress), book.pageCount?.let { "p. ${book.currentPage} of $it" }).joinToString(" · ")
                           else WidgetText.detail(book, pageFirst = false)
                WText(line, p.ink2, 12.sp, GlanceModifier.defaultWeight(), serif = p.family == "soft", italic = p.family == "soft")
                UpdateLink(book) { WPlus(p) }
            }
        }
    }
}

@Composable
private fun LargeUpNext(book: WidgetBook, upNext: List<WidgetBook>, p: WPalette) {
    val context = LocalContext.current
    Column(GlanceModifier.fillMaxSize()) {
        MediumStyled(book, p, tone = false)
        Spacer(GlanceModifier.height(14.dp))
        Box(GlanceModifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.8f).cp())) {}
        Spacer(GlanceModifier.height(12.dp))
        if (upNext.isNotEmpty()) {
            WText("up next", p.ink2, 13.sp, serif = true, italic = true)
            Spacer(GlanceModifier.height(8.dp))
            Row(GlanceModifier.fillMaxWidth()) {
                upNext.take(3).forEach { b ->
                    Column(GlanceModifier.defaultWeight().clickable(actionStartActivity(Widgets.open(context, "quietreading://book/${b.id}")))
                        .semantics { contentDescription = "Up next: ${b.title}" }) {
                        WCover(b, 44.dp, p)
                        Spacer(GlanceModifier.height(6.dp))
                        WText(b.title, p.ink, 11.sp)
                    }
                }
            }
        }
    }
}

// MARK: This week (Large · Modern · Graphite)

class ThisWeekWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = Widgets.snapshot(context)
        val p = WPalette.style(WidgetStyleId.Graphite.palette, "modern")
        provideContent {
            if (!s.isPlus) PlusLocked(s.theme) else WidgetRoot(p, "quietreading://stats") { ThisWeek(s, p) }
        }
    }
}

class ThisWeekReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget = ThisWeekWidget() }

@Composable
private fun ThisWeek(s: WidgetSnapshot, p: WPalette) {
    val pages = if (s.weekPages.size == 7) s.weekPages else List(7) { 0 }
    val total = pages.sum()
    val today = s.weekDays.indexOf(LocalDate.now()).coerceAtLeast(0)
    val context = LocalContext.current
    Column(GlanceModifier.fillMaxSize()) {
        WText("THIS WEEK", p.ink2, 10.sp, weight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.Bottom, modifier = GlanceModifier.semantics { contentDescription = "$total pages this week" }) {
            WText("$total", p.ink, 44.sp)
            Spacer(GlanceModifier.width(6.dp))
            WText("pages", p.ink2, 14.sp, GlanceModifier.padding(bottom = 8.dp))
        }
        Spacer(GlanceModifier.defaultWeight())
        val summary = s.weekDays.zip(pages).joinToString(", ") { (d, n) -> "${d.dayOfWeek.getDisplayName(DateTextStyle.FULL, Locale.getDefault())} $n pages" }
        Image(ImageProvider(weekBars(pages, today, p.ink, p.track)), summary, GlanceModifier.fillMaxWidth().height(72.dp))
        Spacer(GlanceModifier.height(4.dp))
        Row(GlanceModifier.fillMaxWidth()) {
            s.weekDays.forEach { d -> WText(d.dayOfWeek.getDisplayName(DateTextStyle.NARROW, Locale.getDefault()), p.ink2, 10.sp, GlanceModifier.defaultWeight()) }
        }
        Spacer(GlanceModifier.height(12.dp))
        Box(GlanceModifier.fillMaxWidth().height(1.dp).background(p.hairline.cp())) {}
        Spacer(GlanceModifier.height(12.dp))
        s.current?.let { book ->
            Row(GlanceModifier.fillMaxWidth().clickable(actionStartActivity(Widgets.open(context, "quietreading://book/${book.id}"))), verticalAlignment = Alignment.CenterVertically) {
                WCover(book, 30.dp, p)
                Spacer(GlanceModifier.width(12.dp))
                Column(GlanceModifier.defaultWeight().semantics { contentDescription = WidgetText.label(book) }) {
                    WText(book.title, p.ink, 14.sp, weight = FontWeight.Medium)
                    WText(WidgetText.detail(book, pageFirst = false), p.ink2, 11.sp)
                }
                UpdateLink(book) { WPlus(p) }
            }
        }
    }
}

// MARK: Quote (Medium · Plus)

class QuoteWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(MEDIUM))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = Widgets.snapshot(context)
        provideContent { if (!s.isPlus) PlusLocked(s.theme) else QuoteContent(s) }
    }
}

class QuoteReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget = QuoteWidget() }

@Composable
private fun QuoteContent(s: WidgetSnapshot) {
    val c = s.theme.colors()
    val p = WPalette.theme(c).copy(background = listOf(c.soft))
    // One quote a day, stepping through the saved ones.
    val quote = s.quotes.takeIf { it.isNotEmpty() }?.let { it[(LocalDate.now().toEpochDay() % it.size).toInt()] }
    WidgetRoot(p, "quietreading://stats") {
        Column(GlanceModifier.fillMaxSize()) {
            Image(ImageProvider(R.drawable.ic_qs_quote), null, GlanceModifier.size(16.dp), colorFilter = ColorFilter.tint(c.accentInk.cp()))
            Spacer(GlanceModifier.height(8.dp))
            if (quote != null) {
                WText("“${quote.text}”", p.ink, 17.sp, serif = true, maxLines = 4)
                Spacer(GlanceModifier.defaultWeight())
                WText(quote.page?.let { "${quote.book} · p. $it" } ?: quote.book, p.ink, 11.sp)
            } else {
                WText("Lines you save show up here", p.ink, 17.sp, serif = true, maxLines = 2)
                Spacer(GlanceModifier.defaultWeight())
                WText("Add a quote from any book in Quiet Reading.", p.ink, 11.sp, maxLines = 2)
            }
        }
    }
}
