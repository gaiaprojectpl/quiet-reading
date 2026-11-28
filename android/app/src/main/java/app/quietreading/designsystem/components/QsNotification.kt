package app.quietreading.designsystem.components

import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.semibold
import kotlinx.coroutines.delay
import java.util.UUID

enum class NoticeKind { Success, Info, Warning, Error }

data class Notice(
    val title: String,
    val message: String,
    val kind: NoticeKind = NoticeKind.Success,
    val actionTitle: String? = null,
    val action: (() -> Unit)? = null,
    val id: String = UUID.randomUUID().toString(),
)

/**
 * 🧱 Components › Notification (Figma 47:1135): one colourful message, always at the top under the status bar.
 * Hides after 4 s (6 s with an action), swipe up to dismiss, read out by TalkBack.
 * For meaningful moments only (page saved, book added). Saving itself is silent.
 */
class Notifier {
    var current by mutableStateOf<Notice?>(null)
        private set

    fun show(title: String, message: String, kind: NoticeKind = NoticeKind.Success, actionTitle: String? = null, action: (() -> Unit)? = null) {
        current = Notice(title, message, kind, actionTitle, action)
    }

    fun dismiss(id: String? = null) {
        if (id == null || current?.id == id) current = null
    }
}

val LocalNotifier = compositionLocalOf { Notifier() }

@Composable
fun NotificationHost(notifier: Notifier, content: @Composable () -> Unit) {
    val reduce = QsTheme.reduceMotion
    val view = LocalView.current
    Box(Modifier.fillMaxSize()) {
        content()
        val item = notifier.current
        LaunchedEffect(item?.id) {
            if (item == null) return@LaunchedEffect
            view.performHapticFeedback(if (item.kind == NoticeKind.Error) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.CONFIRM)
            delay((if (item.actionTitle == null) QsMotion.toastShort else QsMotion.toastLong).toLong())
            notifier.dismiss(item.id)
        }
        AnimatedVisibility(
            visible = item != null,
            enter = if (reduce) fadeIn(tween(QsMotion.fast)) else slideInVertically(tween(QsMotion.base)) { -it } + fadeIn(tween(QsMotion.base)),
            exit = if (reduce) fadeOut(tween(QsMotion.fast)) else slideOutVertically(tween(QsMotion.base)) { -it } + fadeOut(tween(QsMotion.base)),
            modifier = Modifier.align(Alignment.TopCenter),
        ) {
            item?.let { NotificationCard(it) { notifier.dismiss(it.id) } }
        }
    }
}

@Composable
private fun NotificationCard(item: Notice, onClose: () -> Unit) {
    val c = QsTheme.colors
    val badge = when (item.kind) { NoticeKind.Success -> c.success; NoticeKind.Info -> c.accent; NoticeKind.Warning -> c.warning; NoticeKind.Error -> c.error }
    val bg = when (item.kind) { NoticeKind.Success -> c.successSoft; NoticeKind.Info -> c.soft2; NoticeKind.Warning -> c.warningSoft; NoticeKind.Error -> c.errorSoft }
    val icon = when (item.kind) { NoticeKind.Success -> R.drawable.ic_qs_check; NoticeKind.Info -> R.drawable.ic_qs_info; NoticeKind.Warning -> R.drawable.ic_qs_bell; NoticeKind.Error -> R.drawable.ic_qs_alert }
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Row(
        Modifier.statusBarsPadding().padding(horizontal = QsSpace.s16).padding(top = QsSpace.s4).fillMaxWidth()
            .shadow(9.dp, shape, ambientColor = c.scrim.copy(alpha = 0.12f), spotColor = c.scrim.copy(alpha = 0.12f))
            .background(bg, shape)
            .pointerInput(item.id) { detectVerticalDragGestures { _, drag -> if (drag < -10) onClose() } }
            .semantics { liveRegion = LiveRegionMode.Polite }
            .padding(start = QsSpace.s16, end = QsSpace.s4, top = QsSpace.s12, bottom = QsSpace.s12),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(QsSpace.s32 + QsSpace.s4).background(badge, CircleShape), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = c.onAccent, size = QsSize.iconM)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(item.title, style = QsType.subheadline.semibold(), color = c.ink)
            Text(item.message, style = QsType.subheadline, color = c.ink)
        }
        if (item.actionTitle != null && item.action != null) {
            Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable { item.action.invoke(); onClose() }.padding(horizontal = QsSpace.s8), contentAlignment = Alignment.Center) {
                Text(item.actionTitle, style = QsType.subheadline.semibold(), color = when (item.kind) { NoticeKind.Info -> c.accentInk; else -> badge })
            }
        }
        QsIconButton(R.drawable.ic_qs_close, "Close", tint = c.ink2, onClick = onClose)
    }
}
