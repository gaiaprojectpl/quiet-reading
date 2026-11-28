package app.quietreading.feature.settings

import android.text.format.DateFormat
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.shape.RoundedCornerShape
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.QsButton
import java.util.Calendar

/** Flow 8 › Edit goal. Typed number (never a stepper). Empty or 0 turns the goal off. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalSheet(goal: Int, finishedThisYear: Int, onDismiss: () -> Unit, onSave: (Int) -> Unit) {
    val c = QsTheme.colors
    val year = Calendar.getInstance().get(Calendar.YEAR)
    var text by remember { mutableStateOf(if (goal > 0) goal.toString() else "") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.surface, shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        SheetBody("Reading goal", actions = { QsButton("Save", { onSave(maxOf(0, text.toIntOrNull() ?: 0)) }) }) {
            QsTextField(
                "Books in $year", text, { v -> text = v.filter { it.isDigit() }.take(4) },
                modifier = Modifier.focusRequester(focus), suffix = "books",
                keyboard = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            Text("Type any number. Leave it empty to turn the goal off.", style = QsType.footnote, color = c.ink2)
            InfoBanner("Goals are optional. No streaks, no guilt.")
        }
    }
}

/** Daily reminder time: one gentle reminder at the time you choose. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReminderSheet(minutes: Int, onDismiss: () -> Unit, onSave: (Int) -> Unit) {
    val c = QsTheme.colors
    val state = rememberTimePickerState(minutes / 60, minutes % 60, DateFormat.is24HourFormat(LocalContext.current))
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.surface, shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        SheetBody("Daily reminder", actions = { QsButton("Save", { onSave(state.hour * 60 + state.minute) }) }) {
            Text("One gentle reminder at the time you choose. Never more than once a day.", style = QsType.subheadline, color = c.ink2)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TimePicker(
                    state,
                    colors = TimePickerDefaults.colors(
                        clockDialColor = c.soft2, selectorColor = c.accent, containerColor = c.surface,
                        clockDialSelectedContentColor = c.onAccent, clockDialUnselectedContentColor = c.ink,
                        periodSelectorBorderColor = c.lineStrong, periodSelectorSelectedContainerColor = c.soft,
                        periodSelectorSelectedContentColor = c.ink, periodSelectorUnselectedContentColor = c.ink2,
                        timeSelectorSelectedContainerColor = c.soft, timeSelectorUnselectedContainerColor = c.disabledBg,
                        timeSelectorSelectedContentColor = c.ink, timeSelectorUnselectedContentColor = c.ink,
                    ),
                )
            }
        }
    }
}
