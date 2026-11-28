package app.quietreading.feature.stats

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.toBitmap
import androidx.core.graphics.withTranslation
import app.quietreading.R
import app.quietreading.data.Book
import app.quietreading.data.Covers
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.colors
import app.quietreading.designsystem.headFont
import app.quietreading.designsystem.shapes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * The image people share from Stats and Year in books: soft card, up to three covers,
 * one sentence, a line of numbers and the app name. 1080 px wide – fine for messages and Stories.
 */
object StatsShareCard {
    private const val WIDTH = 1080
    private const val K = WIDTH / 400f   // dp of the iOS card → px

    /** Draws the card and saves it as a PNG in the cache, ready to share. */
    suspend fun file(context: Context, covers: Covers, books: List<Book>, title: String, detail: String?, theme: ThemeId): File? = withContext(Dispatchers.Default) {
        runCatching {
            val c = theme.colors()
            val pad = 32 * K
            val inner = WIDTH - 2 * pad
            val head = runCatching {
                ResourcesCompat.getFont(context, when (theme.headFont().family) {
                    "Fraunces" -> R.font.fraunces; "Lora" -> R.font.lora; "Playfair Display" -> R.font.playfair_display; else -> R.font.newsreader
                })
            }.getOrNull() ?: Typeface.SERIF
            val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = c.ink.toArgb(); textSize = 28 * K; typeface = Typeface.create(head, 500, false) }
            val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = c.ink2.toArgb(); textSize = 15 * K }
            val brandPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = c.accentInk.toArgb(); textSize = 12 * K; typeface = Typeface.create(Typeface.DEFAULT, 600, false) }
            val titleLayout = StaticLayout.Builder.obtain(title, 0, title.length, titlePaint, inner.toInt()).setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
            val detailLayout = detail?.let { StaticLayout.Builder.obtain(it, 0, it.length, detailPaint, inner.toInt()).build() }
            val coverW = 80 * K
            val coverH = coverW * 1.5f
            val bitmaps = books.take(3).map { b -> b.coverFile?.let { BitmapFactory.decodeFile(covers.file(it).path) } to b.title }

            val gap = 16 * K
            var height = pad
            if (bitmaps.isNotEmpty()) height += coverH + gap
            height += titleLayout.height + gap
            if (detailLayout != null) height += detailLayout.height + gap
            height += 8 * K + 20 * K + pad

            val bmp = Bitmap.createBitmap(WIDTH, height.toInt(), Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            canvas.drawColor(c.soft.toArgb())
            var y = pad
            if (bitmaps.isNotEmpty()) {
                val radius = theme.shapes().cover.value * K
                var x = pad
                val fill = Paint(Paint.ANTI_ALIAS_FLAG)
                for ((cover, name) in bitmaps) {
                    val rect = RectF(x, y, x + coverW, y + coverH)
                    if (cover != null) {
                        canvas.save()
                        val path = android.graphics.Path().apply { addRoundRect(rect, radius, radius, android.graphics.Path.Direction.CW) }
                        canvas.clipPath(path)
                        val scale = maxOf(coverW / cover.width, coverH / cover.height)
                        val w = cover.width * scale
                        val h = cover.height * scale
                        canvas.drawBitmap(cover, null, RectF(x + (coverW - w) / 2, y + (coverH - h) / 2, x + (coverW + w) / 2, y + (coverH + h) / 2), fill)
                        canvas.restore()
                    } else {
                        fill.color = c.disabledBg.toArgb()
                        canvas.drawRoundRect(rect, radius, radius, fill)
                        val p = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = c.ink2.toArgb(); textSize = 11 * K }
                        val l = StaticLayout.Builder.obtain(name, 0, name.length, p, (coverW - 8 * K).toInt()).setAlignment(Layout.Alignment.ALIGN_CENTER).setMaxLines(4).build()
                        canvas.withTranslation(x + 4 * K, y + (coverH - l.height) / 2) { l.draw(this) }
                    }
                    x += coverW + 8 * K
                }
                y += coverH + gap
            }
            canvas.withTranslation(pad, y) { titleLayout.draw(this) }
            y += titleLayout.height + gap
            if (detailLayout != null) {
                canvas.withTranslation(pad, y) { detailLayout.draw(this) }
                y += detailLayout.height + gap
            }
            y += 8 * K
            // Logo tile + "Quiet Reading"
            val tile = 20 * K
            val tilePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = c.accent.toArgb() }
            canvas.drawRoundRect(RectF(pad, y, pad + tile, y + tile), 4 * K, 4 * K, tilePaint)
            context.getDrawable(R.drawable.ic_qs_logo)?.let { d ->
                d.setTint(c.bg.toArgb())
                canvas.drawBitmap(d.toBitmap(tile.toInt(), tile.toInt()), pad, y, null)
            }
            canvas.drawText("Quiet Reading", pad + tile + 6 * K, y + tile / 2 + brandPaint.textSize / 3, brandPaint)

            val dir = File(context.cacheDir, "share").apply { mkdirs() }
            val file = File(dir, "My reading – Quiet Reading.png")
            file.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            file
        }.getOrNull()
    }

    /** Opens the Android share sheet with the PNG and a caption (Messages, Instagram, WhatsApp…). */
    fun share(context: Context, file: File, caption: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, caption)
            putExtra(Intent.EXTRA_TITLE, caption)
            clipData = android.content.ClipData.newRawUri(caption, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
