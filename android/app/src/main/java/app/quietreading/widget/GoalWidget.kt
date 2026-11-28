package app.quietreading.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.size
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import app.quietreading.designsystem.WidgetStyleId
import app.quietreading.designsystem.colors

/**
 * Free · Small · Reading goal: the yearly ring with a number (never colour alone). "No rush".
 * Plus readers can pick a Soft tint when adding the widget; without Plus it shows the app theme.
 */
class GoalWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = Widgets.snapshot(context)
        val style = Widgets.styleFor(context, id)?.let { name -> WidgetStyleId.entries.firstOrNull { it.name == name } }
        val p = if (style != null && s.isPlus) WPalette.style(style.palette, style.family) else WPalette.theme(s.theme.colors())
        provideContent { GoalContent(s, p) }
    }
}

class GoalReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget = GoalWidget() }

@Composable
private fun GoalContent(s: WidgetSnapshot, p: WPalette) {
    val fraction = if (s.goal > 0) (s.finishedThisYear.toFloat() / s.goal).coerceAtMost(1f) else 0f
    val caption = if (s.goal > 0) "of ${s.goal} books in ${s.year}" else "books in ${s.year}"
    val label = if (s.goal > 0) "${s.finishedThisYear} of ${s.goal} books in ${s.year}. No rush." else "${s.finishedThisYear} books in ${s.year}"
    WidgetRoot(p, "quietreading://stats") {
        Column(GlanceModifier.fillMaxSize().semantics { contentDescription = label }, horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
            Box(GlanceModifier.size(80.dp), contentAlignment = Alignment.Center) {
                Image(ImageProvider(ring(fraction, p.track, p.accent)), null, GlanceModifier.size(80.dp))
                WText("${s.finishedThisYear}", p.ink, 28.sp, serif = true, weight = FontWeight.Medium)
            }
            Text(caption, style = TextStyle(color = p.ink2.cp(), fontSize = 11.sp, textAlign = TextAlign.Center), maxLines = 2)
            if (s.goal > 0 && s.finishedThisYear < s.goal) WText("No rush", p.ink2, 11.sp, weight = FontWeight.Medium)
        }
    }
}
