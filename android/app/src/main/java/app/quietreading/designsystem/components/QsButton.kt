package app.quietreading.designsystem.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme

enum class QsButtonKind { Primary, Secondary, Outline, Text }

/** 🧱 Components › Button. Full width, 48 dp. */
@Composable
fun QsButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    kind: QsButtonKind = QsButtonKind.Primary,
    enabled: Boolean = true,
) {
    val c = QsTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val (fg, bg) = when (kind) {
        QsButtonKind.Primary -> c.onAccent to (if (pressed) c.accentPressed else c.accent)
        QsButtonKind.Secondary -> c.accentInk to (if (pressed) c.soft else c.soft2)
        QsButtonKind.Outline -> c.accentInk to (if (pressed) c.soft2 else Color.Transparent)
        QsButtonKind.Text -> c.accentInk to (if (pressed) c.soft2 else Color.Transparent)
    }
    Button(
        onClick = onClick,
        enabled = enabled,
        interactionSource = interaction,
        modifier = modifier.fillMaxWidth().heightIn(min = QsSize.button),
        shape = RoundedCornerShape(QsTheme.shapes.btn),
        colors = ButtonDefaults.buttonColors(
            containerColor = bg, contentColor = fg,
            disabledContainerColor = c.disabledBg, disabledContentColor = c.disabledInk,
        ),
        border = if (kind == QsButtonKind.Outline) BorderStroke(QsSize.stroke, c.lineStrong) else null,
        contentPadding = PaddingValues(horizontal = QsSpace.s16),
        elevation = null,
    ) {
        Text(label, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, textAlign = TextAlign.Center)
    }
}
