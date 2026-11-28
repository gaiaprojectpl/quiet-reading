package app.quietreading.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.size
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontFamily
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import app.quietreading.R
import app.quietreading.designsystem.QsColors

/** Colours a widget draws with: the app theme, or a Plus style. */
data class WPalette(
    val background: List<Color>,
    val ink: Color, val ink2: Color, val accent: Color, val track: Color,
    val button: Color, val buttonInk: Color, val hairline: Color,
    /** "theme", "soft", "colourful" or "modern". */
    val family: String,
) {
    companion object {
        fun theme(c: QsColors) = WPalette(listOf(c.surface), c.ink, c.ink2, c.accent, c.chartTrack, c.accent, c.onAccent, Color.Transparent, "theme")
        fun style(p: app.quietreading.designsystem.WidgetPalette, family: String) =
            WPalette(p.background, p.ink, p.ink2, p.accent, p.track, p.button, p.buttonInk, p.hairline, family)
        /** Colourful · Cover tone: the cover's colour with light text on top. */
        fun coverTone(tone: Int?, fallback: Color): WPalette {
            val c = tone?.let { Color(it) } ?: fallback
            val deep = Color(c.red * 0.75f, c.green * 0.75f, c.blue * 0.75f)
            val light = Color(0xFFFFFDF8)
            return WPalette(listOf(c, deep), light, light.copy(alpha = 0.88f), light, Color.White.copy(alpha = 0.25f), light,
                Color(c.red * 0.7f, c.green * 0.7f, c.blue * 0.7f), Color.Transparent, "colourful")
        }
    }
}

fun Color.cp(): ColorProvider = ColorProvider(this)

@Composable
fun WText(
    text: String, color: Color, size: TextUnit, modifier: GlanceModifier = GlanceModifier,
    serif: Boolean = false, weight: FontWeight = FontWeight.Normal, italic: Boolean = false, maxLines: Int = 1,
) {
    Text(
        text, modifier, maxLines = maxLines,
        style = TextStyle(
            color = color.cp(), fontSize = size, fontWeight = weight,
            fontFamily = if (serif) FontFamily.Serif else null,
            fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        ),
    )
}

/** Small cover, or a soft placeholder with the title's initials. */
@Composable
fun WCover(book: WidgetBook, width: Dp, p: WPalette) {
    val cover = book.cover
    if (cover != null) {
        Image(ImageProvider(cover), null, GlanceModifier.size(width, width * 1.5f).cornerRadius(3.dp), contentScale = ContentScale.Crop)
    } else {
        val initials = book.title.split(" ").take(2).mapNotNull { it.firstOrNull()?.toString() }.joinToString("")
        Box(GlanceModifier.size(width, width * 1.5f).cornerRadius(3.dp).background(p.track.cp()), contentAlignment = Alignment.Center) {
            WText(initials, p.ink2, (width.value / 3.2f).sp, serif = true)
        }
    }
}

@Composable
fun WProgress(value: Float, p: WPalette, height: Dp = 4.dp) {
    LinearProgressIndicator(value, GlanceModifier.fillMaxWidth().height(height).cornerRadius(height / 2), p.accent.cp(), p.track.cp())
}

/** "+" circle: opens the page update (progress is always typed). */
@Composable
fun WPlus(p: WPalette, size: Dp = 32.dp, modifier: GlanceModifier = GlanceModifier) {
    Box(
        modifier.size(size).cornerRadius(size / 2).background(p.button.cp()).semantics { contentDescription = "Update my page" },
        contentAlignment = Alignment.Center,
    ) {
        Image(ImageProvider(R.drawable.ic_qs_plus), null, GlanceModifier.size(size * 0.5f), colorFilter = ColorFilter.tint(p.buttonInk.cp()))
    }
}

// Bitmaps for what RemoteViews can't draw: gradients, the goal ring, the ribbon bookmark.

fun gradient(colors: List<Color>, w: Int = 400, h: Int = 400, hairline: Color = Color.Transparent): Bitmap {
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val cs = if (colors.size == 1) listOf(colors[0], colors[0]) else colors
    paint.shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), cs.map { it.toArgb() }.toIntArray(), null, Shader.TileMode.CLAMP)
    canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
    if (hairline.alpha > 0f) {
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 3f; color = hairline.toArgb() }
        canvas.drawRect(1.5f, 1.5f, w - 1.5f, h - 1.5f, line)
    }
    return bmp
}

fun ring(fraction: Float, track: Color, fill: Color, px: Int = 240, stroke: Float = 18f): Bitmap {
    val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val r = RectF(stroke, stroke, px - stroke, px - stroke)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND }
    paint.color = track.toArgb(); canvas.drawArc(r, 0f, 360f, false, paint)
    if (fraction > 0f) { paint.color = fill.toArgb(); canvas.drawArc(r, -90f, 360f * fraction.coerceIn(0f, 1f), false, paint) }
    return bmp
}

/** Silk ribbon bookmark (from the logo) hanging from the top edge of Soft widgets. */
fun ribbon(color: Color): Bitmap {
    val bmp = Bitmap.createBitmap(36, 90, Bitmap.Config.ARGB_8888)
    val path = Path().apply { moveTo(0f, 0f); lineTo(36f, 0f); lineTo(36f, 90f); lineTo(18f, 72f); lineTo(0f, 90f); close() }
    Canvas(bmp).drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color.toArgb() })
    return bmp
}

/** Bar chart for "This week": today in ink, other days in the track colour. */
fun weekBars(pages: List<Int>, today: Int, ink: Color, track: Color, w: Int = 700, h: Int = 220): Bitmap {
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val max = (pages.maxOrNull() ?: 1).coerceAtLeast(1)
    val gap = 26f
    val bw = (w - gap * 6) / 7
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    pages.forEachIndexed { i, p ->
        val bh = maxOf(8f, h * p.toFloat() / max)
        paint.color = (if (i == today) ink else track).toArgb()
        val x = i * (bw + gap)
        canvas.drawRoundRect(RectF(x, h - bh, x + bw, h.toFloat()), 10f, 10f, paint)
    }
    return bmp
}
