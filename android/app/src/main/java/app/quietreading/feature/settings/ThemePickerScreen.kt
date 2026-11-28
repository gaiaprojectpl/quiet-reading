package app.quietreading.feature.settings

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.quietreading.R
import app.quietreading.data.Keys
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.colors
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.headFamily
import app.quietreading.designsystem.headFont
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.shapes

/**
 * Flow 5 › App theme: theme cards drawn in their own colours. Free first, then Plus.
 * Without Plus a Plus theme shows a lock and says it's part of Plus (purchase comes with the Plus screen).
 */
@Composable
fun ThemePickerScreen(onBack: () -> Unit) {
    val c = QsTheme.colors
    val notifier = LocalNotifier.current
    val haptics = LocalHapticFeedback.current
    val (themeRaw, setTheme) = rememberPref(Keys.theme, ThemeId.PeachSage.name)
    val (forceHC, setForceHC) = rememberPref(Keys.forceHighContrast, false)
    val (plus, _) = rememberPref(Keys.plusUnlocked, false)
    val chosen = ThemeId.entries.firstOrNull { it.name == themeRaw } ?: ThemeId.PeachSage

    fun card(id: ThemeId): @Composable (Modifier) -> Unit = { m ->
        val locked = id.requiresPlus && !plus
        ThemeCard(id, selected = !locked && id == chosen, locked = locked, modifier = m) {
            haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
            if (locked) notifier.show("Part of Plus", "${id.displayName} comes with Quiet Reading Plus.", NoticeKind.Info)
            else setTheme(id.name)
        }
    }

    FlowScreen("App theme", onBack = onBack, backLabel = "Settings") {
        SectionLabel("Free")
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            card(ThemeId.PeachSage)(Modifier.weight(1f))
            Spacer(Modifier.weight(1f))
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s4), modifier = Modifier.padding(top = QsSpace.s8)) {
            SectionLabel("Plus")
            QsIcon(R.drawable.ic_qs_crown, tint = c.ink2, size = QsSize.iconS - 2.dp)
        }
        val plusThemes = listOf(ThemeId.ClayCream, ThemeId.BlushIvory, ThemeId.LavenderMist)
        plusThemes.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                pair.forEach { card(it)(Modifier.weight(1f)) }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        if (!plus) Text("Plus themes come with Quiet Reading Plus, a one-time purchase.", style = QsType.footnote, color = c.ink2)

        SectionLabel("Accessibility · always free", Modifier.padding(top = QsSpace.s8))
        QsListCard(rows = listOf({ ToggleRow(R.drawable.ic_qs_eye, "High contrast", checked = forceHC) { setForceHC(it) } }))
        Text(
            "Night follows Dark theme. High contrast also turns on with Contrast in your phone’s accessibility settings.",
            style = QsType.footnote, color = c.ink2,
        )
    }
}

/** Flow 5 › Theme card: a tiny "Reading now" screen in that theme's own colours, radii and heading font. */
@Composable
fun ThemeCard(id: ThemeId, selected: Boolean, locked: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val active = QsTheme.colors
    val p = id.colors()
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        modifier
            .clip(shape)
            .background(p.bg, shape)
            .border(if (selected) QsSize.focusRing else QsSize.stroke, if (selected) active.accent else active.line, shape)
            .pressable(onClick = onClick)
            .selectable(selected, role = Role.RadioButton, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = id.displayName
                this.selected = selected
                if (locked) stateDescription = "Plus, locked"
            }
            .padding(QsSpace.s12),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Image(
                painterResource(R.drawable.cover_winter_tea), null, contentScale = ContentScale.Crop,
                modifier = Modifier.size(36.dp, 54.dp).clip(RoundedCornerShape(maxOf(id.shapes().cover / 2, 2.dp))),
            )
            Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                Text("Reading now", style = TextStyle(fontFamily = id.headFamily(), fontWeight = id.headFont().weight, fontSize = 12.sp), color = p.ink, maxLines = 1)
                Box(Modifier.fillMaxWidth().height(QsSpace.s6).background(p.accent, CircleShape))
                Box(Modifier.fillMaxWidth().height(QsSpace.s6).background(p.accent.copy(alpha = 0.75f), CircleShape))
                Box(Modifier.fillMaxWidth().height(QsSpace.s6).background(p.soft2, CircleShape))
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
            listOf(p.bg, p.soft, p.soft2, p.accent, p.ink).forEach { col ->
                Box(Modifier.size(10.dp).background(col, CircleShape).border(QsSize.stroke, p.line, CircleShape))
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(id.displayName, style = QsType.footnote.medium(), color = p.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            if (locked) QsIcon(R.drawable.ic_qs_lock, tint = p.ink2, size = QsSize.iconS)
            else if (selected) QsIcon(R.drawable.ic_qs_check, tint = p.accentInk, size = QsSize.iconS)
        }
    }
}
