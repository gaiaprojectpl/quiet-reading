package app.quietreading.designsystem.components

import androidx.annotation.DrawableRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import kotlin.math.roundToInt

/** A themed `qs.*` icon (Tabler outline). Decorative unless [label] is given. */
@Composable
fun QsIcon(@DrawableRes icon: Int, modifier: Modifier = Modifier, tint: Color = QsTheme.colors.ink, size: androidx.compose.ui.unit.Dp = QsSize.iconM, label: String? = null) {
    Icon(painterResource(icon), contentDescription = label, tint = tint, modifier = modifier.size(size))
}

/** 48 dp round icon button (search, sort, share…). */
@Composable
fun QsIconButton(@DrawableRes icon: Int, label: String, modifier: Modifier = Modifier, tint: Color = QsTheme.colors.ink, onClick: () -> Unit) {
    Box(
        modifier.size(QsSize.touchAndroid).clip(CircleShape).pressable(label = label, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { QsIcon(icon, tint = tint, size = QsSize.iconL) }
}

/** 🧱 Components › Chip. Selected: soft2 fill, 1.5 dp accent border and a check. Compact pill, 48 dp touch. */
@Composable
fun QsChip(title: String, selected: Boolean = false, modifier: Modifier = Modifier, @DrawableRes icon: Int? = null, onClick: () -> Unit) {
    val c = QsTheme.colors
    val haptics = LocalHapticFeedback.current
    Box(
        modifier
            .heightIn(min = QsSize.touchAndroid)
            .selectable(selected = selected, role = Role.Checkbox, onClick = {
                haptics.performHapticFeedback(HapticFeedbackType.SegmentTick); onClick()
            }),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier
                .heightIn(min = QsSize.buttonSmall - QsSpace.s8)
                .background(if (selected) c.soft2 else Color.Transparent, CircleShape)
                .border(if (selected) 1.5.dp else QsSize.stroke, if (selected) c.accent else c.line, CircleShape)
                .padding(horizontal = QsSpace.s12, vertical = QsSpace.s6),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(QsSpace.s6),
        ) {
            val i = icon ?: if (selected) R.drawable.ic_qs_check else null
            if (i != null) QsIcon(i, tint = c.accentInk, size = QsSize.iconS)
            Text(title, style = QsType.subheadline.medium(), color = c.ink)
        }
    }
}

/** Chips (and tags) laid out left to right, wrapping onto new lines. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChipFlow(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) { content() }
}

/** Surface card (radius card, 1 dp line border). */
@Composable
fun QsCard(modifier: Modifier = Modifier, padding: androidx.compose.ui.unit.Dp = QsSpace.s16, content: @Composable ColumnScope.() -> Unit) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        modifier.fillMaxWidth().clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape).padding(padding),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
        content = content,
    )
}

/** 🧱 Components › List row: icon tile, title, optional subtitle and value, chevron when tappable. */
@Composable
fun QsListRow(@DrawableRes icon: Int, title: String, subtitle: String? = null, value: String? = null, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    val c = QsTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.pressable(onClick = onClick) else Modifier)
            .semantics(mergeDescendants = true) {}
            .heightIn(min = QsSize.touchAndroid)
            .padding(QsSpace.s16),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        Box(Modifier.size(QsSpace.s40).background(c.soft2, RoundedCornerShape(QsTheme.shapes.field)), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = c.accentInk, size = QsSize.iconM + 2.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(title, style = QsType.body.medium(), color = c.ink)
            if (subtitle != null) Text(subtitle, style = QsType.footnote, color = c.ink2)
        }
        if (value != null) Text(value, style = QsType.subheadline, color = c.ink2)
        if (onClick != null) QsIcon(R.drawable.ic_qs_chevron, tint = c.ink2, size = QsSize.iconS + 2.dp)
    }
}

/** Surface card holding list rows with dividers between them. */
@Composable
fun QsListCard(modifier: Modifier = Modifier, rows: List<@Composable () -> Unit>) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(modifier.fillMaxWidth().clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape)) {
        rows.forEachIndexed { i, row ->
            if (i > 0) HorizontalDivider(thickness = QsSize.stroke, color = c.line)
            row()
        }
    }
}

/** 🧱 Components › Progress bar. Track chartTrack, fill accent. M = 8 dp (cards), S = 4 dp (grid tiles). */
@Composable
fun QsProgressBar(value: Float, modifier: Modifier = Modifier, small: Boolean = false) {
    val c = QsTheme.colors
    val v by animateFloatAsState(value.coerceIn(0f, 1f), tween(if (QsTheme.reduceMotion) 0 else QsMotion.slow), label = "progress")
    Box(
        modifier.fillMaxWidth().height(if (small) QsSpace.s4 else QsSpace.s8).clip(CircleShape).background(c.chartTrack)
            .semantics { stateDescription = "${(value * 100).roundToInt()} percent" },
    ) {
        Box(Modifier.fillMaxWidth(v).height(if (small) QsSpace.s4 else QsSpace.s8).clip(CircleShape).background(c.accent))
    }
}

/** 🧱 Components › Empty state. Title = what is true now; message = one calm sentence. */
@Composable
fun EmptyState(@DrawableRes icon: Int, title: String, message: String, modifier: Modifier = Modifier) {
    val c = QsTheme.colors
    Column(
        modifier.fillMaxWidth().padding(vertical = QsSpace.s32).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(QsSize.coverM + QsSpace.s8).background(c.soft2, CircleShape), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = c.accentInk, size = QsSize.iconL * 1.5f)
        }
        Text(title, style = QsTheme.headline(22), color = c.ink, textAlign = TextAlign.Center)
        Text(message, style = QsType.subheadline, color = c.ink2, textAlign = TextAlign.Center)
    }
}

/** 🧱 Components › Banner (info / error). Inline, calm, never blocking. */
@Composable
fun InfoBanner(message: String, modifier: Modifier = Modifier, error: Boolean = false) {
    val c = QsTheme.colors
    Row(
        modifier.fillMaxWidth().background(if (error) c.errorSoft else c.soft2, RoundedCornerShape(QsTheme.shapes.field))
            .padding(QsSpace.s12).semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        QsIcon(if (error) R.drawable.ic_qs_alert else R.drawable.ic_qs_info, tint = if (error) c.error else c.ink)
        Text(message, style = QsType.subheadline, color = c.ink, modifier = Modifier.weight(1f))
    }
}

/** 🧱 Components › Logo: bookmark "q" on an accent tile + the wordmark in the heading font. */
@Composable
fun QsLogo(modifier: Modifier = Modifier, showWordmark: Boolean = true) {
    val c = QsTheme.colors
    Row(
        modifier.semantics(mergeDescendants = true) { contentDescription = "Quiet Reading"; heading() },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(38.4.dp).background(c.accent, RoundedCornerShape(9.6.dp)), contentAlignment = Alignment.Center) {
            Icon(painterResource(R.drawable.ic_qs_logo), null, tint = c.bg, modifier = Modifier.size(38.4.dp))
        }
        if (showWordmark) Text("Quiet Reading", style = QsTheme.headline(24), color = c.ink)
    }
}

/** 🧱 Components › Segmented control: soft2 track, the selected segment on surface. */
@Composable
fun <T> QsSegmented(options: List<Pair<T, String>>, selection: T, modifier: Modifier = Modifier, onSelect: (T) -> Unit) {
    val c = QsTheme.colors
    val haptics = LocalHapticFeedback.current
    Row(
        modifier.fillMaxWidth().background(c.soft2, RoundedCornerShape(QsTheme.shapes.field)).padding(QsSpace.s4),
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        options.forEach { (value, title) ->
            val selected = value == selection
            Box(
                Modifier.weight(1f).heightIn(min = QsSize.touchAndroid - QsSpace.s8)
                    .clip(RoundedCornerShape(QsTheme.shapes.inner))
                    .background(if (selected) c.surface else Color.Transparent)
                    .selectable(selected, role = Role.Tab) { haptics.performHapticFeedback(HapticFeedbackType.SegmentTick); onSelect(value) },
                contentAlignment = Alignment.Center,
            ) {
                Text(title, style = if (selected) QsType.subheadline.semibold() else QsType.subheadline, color = c.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** 🧱 Components › Rating. Five stars in accent; tap a star for a whole star, tap again for a half. */
@Composable
fun QsStarRating(value: Double?, modifier: Modifier = Modifier, onChange: (Double?) -> Unit) {
    val c = QsTheme.colors
    val haptics = LocalHapticFeedback.current
    Row(
        modifier.semantics(mergeDescendants = true) {
            contentDescription = "Rating"
            stateDescription = value?.let { "${if (it % 1.0 == 0.0) it.toInt() else it} stars" } ?: "Not rated"
        },
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        for (i in 1..5) {
            val v = value ?: 0.0
            val icon = when {
                v >= i -> R.drawable.ic_qs_star_fill
                v >= i - 0.5 -> R.drawable.ic_qs_star_half
                else -> R.drawable.ic_qs_star_empty
            }
            Box(Modifier.size(QsSize.touchAndroid).clip(CircleShape).pressable {
                haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                onChange(if (value == i.toDouble()) i - 0.5 else i.toDouble())
            }, contentAlignment = Alignment.Center) {
                Icon(painterResource(icon), null, tint = c.accent, modifier = Modifier.size(36.dp))
            }
        }
    }
}

/** Small section heading ("Up next", "Also reading"). */
@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(modifier.fillMaxWidth().widthIn(min = 0.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = QsTheme.headline(20), color = QsTheme.colors.ink, modifier = Modifier.weight(1f).semantics { heading() })
        trailing()
    }
}
