package app.quietreading.designsystem.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.semibold

/** Figma property "Priority". */
enum class QsButtonKind { Primary, Secondary, Outline, Text, Destructive }
enum class QsButtonSize { Large, Small }

/**
 * 🧱 Components › Button (Figma 47:165). Full width.
 * Primary = filled accent (one per screen) · Secondary = accent border · Outline = neutral border ·
 * Text = link style · Destructive. Large 48 dp / Small 40 dp, touch target ≥ 48 dp.
 */
@Composable
fun QsButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    kind: QsButtonKind = QsButtonKind.Primary,
    size: QsButtonSize = QsButtonSize.Large,
    enabled: Boolean = true,
) {
    val c = QsTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val (fg, bg, border) = if (!enabled) when (kind) {
        QsButtonKind.Primary, QsButtonKind.Destructive -> Triple(c.disabledInk, c.disabledBg, Color.Transparent)
        QsButtonKind.Secondary -> Triple(c.disabledInk, Color.Transparent, c.disabledInk)
        QsButtonKind.Outline -> Triple(c.disabledInk, c.disabledBg, c.disabledInk)
        QsButtonKind.Text -> Triple(c.disabledInk, Color.Transparent, Color.Transparent)
    } else when (kind) {
        QsButtonKind.Primary -> Triple(c.onAccent, if (pressed) c.accentPressed else c.accent, Color.Transparent)
        QsButtonKind.Secondary -> Triple(c.accentInk, if (pressed) c.soft2 else Color.Transparent, if (pressed) c.accentPressed else c.accent)
        QsButtonKind.Outline -> Triple(c.ink, if (pressed) c.infoSoft else Color.Transparent, c.lineStrong)
        QsButtonKind.Text -> Triple(c.accentInk, if (pressed) c.soft2 else Color.Transparent, Color.Transparent)
        QsButtonKind.Destructive -> Triple(c.onAccent, c.error, Color.Transparent)
    }
    val bgAnim by animateColorAsState(bg, tween(QsMotion.fast), label = "bg")
    val scale by animateFloatAsState(if (pressed && !QsTheme.reduceMotion) 0.98f else 1f, tween(QsMotion.fast), label = "scale")
    val shape = RoundedCornerShape(QsTheme.shapes.btn)
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = QsSize.touchAndroid)
            .scale(scale)
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = if (size == QsButtonSize.Large) QsSize.button else QsSize.buttonSmall)
                .background(bgAnim, shape)
                .border(BorderStroke(QsSize.stroke, border), shape)
                .padding(horizontal = if (size == QsButtonSize.Large) QsSpace.s24 else QsSpace.s16, vertical = QsSpace.s8),
            contentAlignment = Alignment.Center,
        ) {
            Text(label, color = fg, style = (if (size == QsButtonSize.Large) QsType.body else QsType.subheadline).semibold(), textAlign = TextAlign.Center)
        }
    }
}

/** Press feedback for tappable cards and tiles: a slight settle (only a dim with Reduce Motion). */
@Composable
fun Modifier.pressable(enabled: Boolean = true, role: Role = Role.Button, label: String? = null, onClick: () -> Unit): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val reduce = QsTheme.reduceMotion
    val scale by animateFloatAsState(if (pressed && !reduce) 0.97f else 1f, tween(QsMotion.fast), label = "press")
    val alpha by animateFloatAsState(if (pressed) 0.85f else 1f, tween(QsMotion.fast), label = "dim")
    return this
        .scale(scale)
        .alpha(alpha)
        .clickable(interaction, indication = null, enabled = enabled, role = role, onClickLabel = label, onClick = onClick)
}
