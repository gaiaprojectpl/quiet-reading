package app.quietreading.feature.book

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** All books, or null while the database is still loading. */
@Composable
fun rememberAllBooks(): List<Book>? {
    val library = LocalApp.current.library
    val books by library.books.collectAsState(initial = null)
    return books
}

/** Work that must outlive the screen (Undo after the update screen has closed). */
internal val bookScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

/** "12 March" / "12 March 2026" in the reader's locale. */
internal fun dayMonth(millis: Long, year: Boolean = false): String =
    DateTimeFormatter.ofPattern(if (year) "d MMMM yyyy" else "d MMMM", Locale.getDefault())
        .format(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()))

internal fun isRecent(millis: Long) = System.currentTimeMillis() - millis < 15 * DateUtils.SECOND_IN_MILLIS

/** "4.5" or "4" */
internal fun starsText(v: Double) = if (v % 1.0 == 0.0) v.toInt().toString() else v.toString()

/**
 * Input field: 40 dp min height, 1 dp lineStrong border, focus ring in `focus`, error = red border.
 * The label stays neutral (Figma rules).
 */
@Composable
fun QsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    number: Boolean = false,
    error: Boolean = false,
    singleLine: Boolean = true,
    minLines: Int = 1,
    textStyle: TextStyle = QsType.body,
    focusRequester: FocusRequester? = null,
    contentPadding: Dp = QsSpace.s16,
    trailing: @Composable () -> Unit = {},
) {
    val c = QsTheme.colors
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(QsTheme.shapes.field)
    // The cursor starts at the end (typing a new page right after the old one).
    var field by remember { mutableStateOf(TextFieldValue(value, TextRange(value.length))) }
    if (field.text != value) field = TextFieldValue(value, TextRange(value.length))
    BasicTextField(
        value = field,
        onValueChange = { field = it; if (it.text != value) onValueChange(it.text) },
        singleLine = singleLine,
        minLines = minLines,
        textStyle = textStyle.copy(color = if (error) c.error else c.ink),
        cursorBrush = SolidColor(c.accent),
        keyboardOptions = if (number) KeyboardOptions(keyboardType = KeyboardType.Number) else KeyboardOptions.Default,
        modifier = modifier
            .fillMaxWidth()
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .onFocusChanged { focused = it.isFocused }
            .semantics { contentDescription = placeholder },
        decorationBox = { inner ->
            Row(
                Modifier
                    .heightIn(min = QsSize.field)
                    .background(c.surface, shape)
                    .border(
                        if (focused && !error) QsSize.focusRing else QsSize.stroke,
                        when { error -> c.error; focused -> c.focus; else -> c.lineStrong }, shape,
                    )
                    .padding(horizontal = contentPadding, vertical = QsSpace.s8),
                verticalAlignment = if (singleLine) Alignment.CenterVertically else Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
            ) {
                Box(Modifier.weight(1f)) {
                    if (value.isEmpty()) Text(placeholder, style = textStyle, color = c.ink2)
                    inner()
                }
                trailing()
            }
        },
    )
}

/** Field with a neutral label above ("Page", "Note (optional)"). */
@Composable
fun LabeledField(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        Text(label, style = QsType.footnote.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Medium), color = QsTheme.colors.ink2)
        content()
    }
}

/** Bottom sheet in the theme: surface, sheet radius, 20 dp sides, 24 dp above the bottom line. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QsSheet(onDismiss: () -> Unit, skipPartial: Boolean = true, content: @Composable ColumnScope.() -> Unit) {
    val c = QsTheme.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = skipPartial),
        containerColor = c.surface,
        contentColor = c.ink,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
            content = content,
        )
    }
}
