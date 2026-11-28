package app.quietreading.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.lifecycle.lifecycleScope
import app.quietreading.QuietReadingApplication
import app.quietreading.R
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.QuietReadingTheme
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.WidgetStyleId
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsIcon
import kotlinx.coroutines.launch

/**
 * Opens when a Plus-style widget is added (and when it's edited): choose Soft, Colourful or the app theme.
 * Without Plus the choice is kept but the widget shows the app theme (Goal) or the calm Plus card.
 */
class WidgetStyleActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val isGoal = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider?.className?.endsWith("GoalReceiver") == true
        val options: List<Pair<String, String>> = if (isGoal) {
            listOf("appTheme" to "App theme") + WidgetStyleId.entries.filter { it.family == "soft" }.map { it.name to "Soft · ${it.displayName}" }
        } else {
            readingStyles.map { s -> s to when (s) { "coverTone" -> "Colourful · Cover tone"; else -> WidgetStyleId.valueOf(s).let { "${it.family.replaceFirstChar(Char::uppercase)} · ${it.displayName}" } } }
        }
        val env = (application as QuietReadingApplication).env
        setContent {
            CompositionLocalProvider(LocalApp provides env) {
                val (themeRaw, _) = rememberPref(Keys.theme, ThemeId.PeachSage.name)
                val (isPlus, _) = rememberPref(Keys.plusUnlocked, false)
                val theme = ThemeId.entries.firstOrNull { it.name == themeRaw } ?: ThemeId.PeachSage
                QuietReadingTheme(theme, isPlus = isPlus) {
                    var selected by remember { mutableStateOf(Widgets.style(this, widgetId) ?: options.first().first) }
                    FlowScreen(
                        "Choose a style", onBack = { finish() }, closeInstead = true, backLabel = "Cancel",
                        actions = { QsButton("Add widget", { save(widgetId, selected) }) },
                    ) {
                        if (!isPlus && !(isGoal && selected == "appTheme")) InfoBanner("Styles are part of Plus. Without Plus the widget shows your app theme.")
                        options.forEach { (value, title) -> StyleRow(value, title, value == selected) { selected = value } }
                    }
                }
            }
        }
    }

    private fun save(widgetId: Int, style: String) {
        Widgets.setStyle(this, widgetId, style)
        lifecycleScope.launch {
            Widgets.refresh(this@WidgetStyleActivity)
            setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            finish()
        }
    }
}

@androidx.compose.runtime.Composable
private fun StyleRow(value: String, title: String, selected: Boolean, onClick: () -> Unit) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    val swatch: Brush = when (value) {
        "appTheme" -> Brush.linearGradient(listOf(c.surface, c.soft))
        "coverTone" -> Brush.linearGradient(listOf(c.accent, c.accentPressed))
        else -> Brush.linearGradient(WidgetStyleId.valueOf(value).palette.background.let { if (it.size == 1) it + it else it })
    }
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid)
            .background(if (selected) c.soft2 else c.surface, shape)
            .border(if (selected) 1.5.dp else QsSize.stroke, if (selected) c.accent else c.line, shape)
            .selectable(selected, role = Role.RadioButton, onClick = onClick)
            .padding(QsSpace.s12),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(QsSpace.s40).background(swatch, RoundedCornerShape(QsTheme.shapes.inner)).border(QsSize.stroke, c.line, RoundedCornerShape(QsTheme.shapes.inner)))
        Text(title, style = QsType.body, color = c.ink, modifier = Modifier.weight(1f))
        if (selected) QsIcon(R.drawable.ic_qs_check, tint = c.accentInk)
    }
}
