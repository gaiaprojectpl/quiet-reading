package app.quietreading.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
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
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
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
import app.quietreading.designsystem.colors

val SMALL = DpSize(110.dp, 110.dp)
val MEDIUM = DpSize(250.dp, 110.dp)
val LARGE = DpSize(250.dp, 250.dp)

/**
 * Free · Reading now, in the app theme. "+" / Update opens the page update (typed);
 * the rest of the widget opens the book. Empty: "Nothing in progress" opens Add.
 */
class ReadingNowWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = Widgets.snapshot(context)
        provideContent { ReadingNowContent(snapshot) }
    }
}

class ReadingNowReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget = ReadingNowWidget() }

/** Root of every widget: rounded, system widget background, padded. */
@Composable
fun WidgetRoot(p: WPalette, link: String?, modifier: GlanceModifier = GlanceModifier, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val bg = if (p.background.size > 1 || p.hairline.alpha > 0f) GlanceModifier.background(ImageProvider(gradient(p.background, hairline = p.hairline)))
             else GlanceModifier.background(p.background.first().cp())
    Box(
        GlanceModifier.fillMaxSize().appWidgetBackground().cornerRadius(20.dp).then(bg)
            .then(if (link != null) GlanceModifier.clickable(actionStartActivity(Widgets.open(context, link))) else GlanceModifier)
            .then(modifier).padding(14.dp),
    ) { content() }
}

@Composable
private fun ReadingNowContent(s: WidgetSnapshot) {
    val p = WPalette.theme(s.theme.colors())
    val book = s.current
    val medium = LocalSize.current.width >= MEDIUM.width
    WidgetRoot(p, book?.let { "quietreading://book/${it.id}" } ?: "quietreading://add") {
        when {
            book == null -> NothingInProgress(p, medium)
            medium -> MediumReading(book, p)
            else -> SmallReading(book, p)
        }
    }
}

@Composable
fun NothingInProgress(p: WPalette, medium: Boolean) {
    Column(GlanceModifier.fillMaxSize()) {
        Image(ImageProvider(R.drawable.ic_qs_book), null, GlanceModifier.size(20.dp), colorFilter = ColorFilter.tint(p.accent.cp()))
        Spacer(GlanceModifier.defaultWeight())
        WText("Nothing in progress", p.ink, if (medium) 18.sp else 15.sp, serif = true, maxLines = 2)
        WText("Tap to add the book you're reading.", p.ink2, 11.sp, maxLines = 2)
    }
}

@Composable
private fun UpdateTarget(book: WidgetBook, content: @Composable () -> Unit) {
    val context = LocalContext.current
    Box(GlanceModifier.clickable(actionStartActivity(Widgets.open(context, "quietreading://update/${book.id}")))
        .semantics { contentDescription = "Update my page in ${book.title}" }) { content() }
}

@Composable
private fun SmallReading(book: WidgetBook, p: WPalette) {
    Column(GlanceModifier.fillMaxSize().semantics { contentDescription = WidgetText.label(book) }) {
        Row(GlanceModifier.fillMaxWidth()) {
            WCover(book, 32.dp, p)
            Spacer(GlanceModifier.defaultWeight())
            UpdateTarget(book) { WPlus(p, 30.dp) }
        }
        Spacer(GlanceModifier.defaultWeight())
        WText(book.title, p.ink, 15.sp, serif = true, weight = FontWeight.Medium, maxLines = 2)
        book.progress?.let { Spacer(GlanceModifier.height(4.dp)); WProgress(it, p); Spacer(GlanceModifier.height(4.dp)) }
        WText(WidgetText.pageLine(book), p.ink2, 11.sp)
    }
}

@Composable
private fun MediumReading(book: WidgetBook, p: WPalette) {
    Row(GlanceModifier.fillMaxSize()) {
        WCover(book, 68.dp, p)
        Spacer(GlanceModifier.width(12.dp))
        Column(GlanceModifier.defaultWeight().fillMaxSize().semantics { contentDescription = WidgetText.label(book) }) {
            WText("READING NOW", p.ink2, 9.sp, weight = FontWeight.Medium)
            WText(book.title, p.ink, 17.sp, serif = true, weight = FontWeight.Medium, maxLines = 2)
            if (book.author.isNotEmpty()) WText(book.author, p.ink2, 11.sp)
            Spacer(GlanceModifier.defaultWeight())
            book.progress?.let { WProgress(it, p); Spacer(GlanceModifier.height(6.dp)) }
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                val detail = listOfNotNull(
                    if (book.currentPage > 0) book.pageCount?.let { "p. ${book.currentPage} of $it" } ?: "p. ${book.currentPage}" else book.pageCount?.let { "$it pages" },
                    WidgetText.timeLeft(book.minutesLeft),
                ).joinToString(" · ")
                WText(detail, p.ink2, 11.sp, GlanceModifier.defaultWeight())
                UpdateTarget(book) {
                    Box(GlanceModifier.height(30.dp).cornerRadius(15.dp).background(p.accent.cp()).padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
                        WText("Update", p.buttonInk, 12.sp, weight = FontWeight.Medium)
                    }
                }
            }
        }
    }
}
