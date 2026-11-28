package app.quietreading.feature.settings

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import java.io.ByteArrayOutputStream
import java.io.File

/** Profile photo stored as a small JPEG in the app's files. */
object Avatar {
    private fun file(context: Context) = File(context.filesDir, "avatar.jpg")

    fun load(context: Context): ImageBitmap? =
        file(context).takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path)?.asImageBitmap() }

    fun save(context: Context, bitmap: Bitmap?) {
        if (bitmap == null) { file(context).delete(); return }
        val side = 512
        val scaled = if (bitmap.width > side || bitmap.height > side) {
            val f = side.toFloat() / maxOf(bitmap.width, bitmap.height)
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * f).toInt(), (bitmap.height * f).toInt(), true)
        } else bitmap
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
        file(context).writeBytes(out.toByteArray())
    }
}

/** Round profile photo, or the reader's initial on soft. */
@Composable
fun AvatarView(image: ImageBitmap?, name: String, size: Dp) {
    val c = QsTheme.colors
    Box(Modifier.size(size).clip(CircleShape).background(c.soft).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
        if (image != null) Image(image, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        else Text(name.take(1).uppercase(), style = QsTheme.headline((size.value * 0.42f).toInt()), color = c.accentInk)
    }
}

/** Uppercase section label above a list card ("APPEARANCE"). */
@Composable
fun SettingsSection(title: String, rows: List<@Composable () -> Unit>) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        SectionLabel(title)
        QsListCard(rows = rows)
    }
}

@Composable
fun SectionLabel(title: String, modifier: Modifier = Modifier) {
    Text(
        title.uppercase(), style = QsType.caption.semibold().copy(letterSpacing = 0.72.sp), color = QsTheme.colors.ink2,
        modifier = modifier.semantics { heading() },
    )
}

/** A themed on/off switch. */
@Composable
fun QsSwitch(checked: Boolean, onChange: ((Boolean) -> Unit)?) {
    val c = QsTheme.colors
    Switch(
        checked, onChange,
        colors = SwitchDefaults.colors(
            checkedTrackColor = c.accent, checkedThumbColor = c.onAccent,
            uncheckedTrackColor = c.disabledBg, uncheckedThumbColor = c.lineStrong, uncheckedBorderColor = c.lineStrong,
        ),
    )
}

/** List row with a switch: the whole row toggles (one TalkBack element, "Monthly recap, switch, off"). */
@Composable
fun ToggleRow(@DrawableRes icon: Int?, title: String, subtitle: String? = null, checked: Boolean, onChange: (Boolean) -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid)
            .toggleable(checked, role = Role.Switch, onValueChange = onChange)
            .padding(QsSpace.s16),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        if (icon != null) IconTile(icon)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(title, style = QsType.body.medium(), color = c.ink)
            if (subtitle != null) Text(subtitle, style = QsType.footnote, color = c.ink2)
        }
        QsSwitch(checked, null)
    }
}

/** List row look for actions (Export, Delete everything); destructive = error colours. */
@Composable
fun ActionRow(@DrawableRes icon: Int, title: String, subtitle: String? = null, destructive: Boolean = false, onClick: () -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).pressable(onClick = onClick).semantics(mergeDescendants = true) {}.padding(QsSpace.s16),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        IconTile(icon, destructive)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(title, style = QsType.body.medium(), color = if (destructive) c.error else c.ink)
            if (subtitle != null) Text(subtitle, style = QsType.footnote, color = c.ink2)
        }
    }
}

@Composable
fun IconTile(@DrawableRes icon: Int, destructive: Boolean = false) {
    val c = QsTheme.colors
    Box(Modifier.size(QsSpace.s40).background(if (destructive) c.errorSoft else c.soft2, RoundedCornerShape(QsTheme.shapes.field)), contentAlignment = Alignment.Center) {
        QsIcon(icon, tint = if (destructive) c.error else c.accentInk, size = QsSize.iconM + 2.dp)
    }
}

/** 🧱 Components › Input: label above, 40 dp field with 1 dp lineStrong border (focus ring / error red). */
@Composable
fun QsTextField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    prefix: String? = null,
    suffix: String? = null,
    error: Boolean = false,
    keyboard: KeyboardOptions = KeyboardOptions.Default,
    singleLine: Boolean = true,
) {
    val c = QsTheme.colors
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(QsTheme.shapes.field)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        Text(label, style = QsType.footnote.medium(), color = c.ink2)
        BasicTextField(
            value, onChange,
            modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused }.semantics { contentDescription = label },
            textStyle = QsType.body.copy(color = c.ink),
            singleLine = singleLine,
            keyboardOptions = keyboard,
            cursorBrush = SolidColor(c.accent),
            decorationBox = { inner ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).background(c.surface, shape)
                        .border(
                            if (focused || error) QsSize.focusRing else QsSize.stroke,
                            when { error -> c.error; focused -> c.focus; else -> c.lineStrong }, shape,
                        )
                        .padding(horizontal = QsSpace.s16, vertical = QsSpace.s8),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(QsSpace.s2),
                ) {
                    if (prefix != null) Text(prefix, style = QsType.body, color = c.ink2)
                    Box(Modifier.weight(1f)) { inner() }
                    if (suffix != null) Text(suffix, style = QsType.body, color = c.ink2)
                }
            },
        )
    }
}

/** Calm two-button dialog (title + one sentence). */
@Composable
fun QsDialog(
    title: String,
    message: String,
    confirm: String,
    onConfirm: () -> Unit,
    dismiss: String,
    onDismiss: () -> Unit,
    destructive: Boolean = false,
) {
    val c = QsTheme.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        title = { Text(title, style = QsTheme.headline(22), color = c.ink) },
        text = { Text(message, style = QsType.body, color = c.ink2) },
        confirmButton = { TextButton(onConfirm) { Text(confirm, style = QsType.body.semibold(), color = if (destructive) c.error else c.accentInk) } },
        dismissButton = { TextButton(onDismiss) { Text(dismiss, style = QsType.body, color = c.accentInk) } },
    )
}

/** Sheet body: title, content, and the button 24 dp above the bottom line. */
@Composable
fun SheetBody(title: String, actions: @Composable ColumnScope.() -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = QsSpace.s20).padding(bottom = QsSpace.s24),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        Text(title, style = QsTheme.headline(24), color = QsTheme.colors.ink, modifier = Modifier.semantics { heading() })
        content()
        Column(Modifier.padding(top = QsSpace.s8), verticalArrangement = Arrangement.spacedBy(QsSpace.s12), content = actions)
    }
}
