package app.quietreading.feature.add

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.medium
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Work that should finish even when the screen closes (saving a cover after "Book added"). */
internal val AppScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

/**
 * Whether the phone is online. Offline is never an error: saving always works and
 * covers / details fill in later (Flow 10 › Offline & errors).
 */
@Composable
fun rememberIsOnline(): Boolean {
    val context = LocalContext.current
    val cm = remember { context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager }
    var online by remember {
        mutableStateOf(cm.getNetworkCapabilities(cm.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true)
    }
    DisposableEffect(cm) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { online = true }
            override fun onLost(network: Network) {
                online = cm.getNetworkCapabilities(cm.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
            }
        }
        runCatching { cm.registerDefaultNetworkCallback(callback) }
        onDispose { runCatching { cm.unregisterNetworkCallback(callback) } }
    }
    return online
}

/** Opens this app's page in system Settings (camera allowed again, etc.). */
fun Context.openAppSettings() {
    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

/** Input (40 dp, 1 dp lineStrong border, field radius) with an optional label above and leading icon. */
@Composable
fun QsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    label: String? = null,
    leadingIcon: Int? = null,
    imeAction: ImeAction = ImeAction.Done,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Sentences,
    onSubmit: () -> Unit = {},
) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.field)
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        if (label != null) Text(label, style = QsType.footnote.medium(), color = c.ink2, modifier = Modifier.clearAndSetSemantics {})
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = QsType.body.copy(color = c.ink),
            cursorBrush = SolidColor(c.accent),
            keyboardOptions = KeyboardOptions(capitalization = capitalization, imeAction = imeAction),
            keyboardActions = KeyboardActions(onAny = { onSubmit() }),
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = label ?: placeholder },
            decorationBox = { inner ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).background(c.surface, shape)
                        .border(QsSize.stroke, c.lineStrong, shape).padding(horizontal = QsSpace.s16),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
                ) {
                    if (leadingIcon != null) app.quietreading.designsystem.components.QsIcon(leadingIcon, tint = c.ink2, size = QsSize.iconM)
                    Box(Modifier.weight(1f)) {
                        if (value.isEmpty()) Text(placeholder, style = QsType.body, color = c.ink2)
                        inner()
                    }
                }
            },
        )
    }
}

/** Loading placeholder in the real layout (Flow 10: disabledBg, no shimmer). */
@Composable
fun SkeletonRow() {
    val c = QsTheme.colors
    Row(Modifier.fillMaxWidth().padding(QsSpace.s12).clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(44.dp, 66.dp).background(c.disabledBg, RoundedCornerShape(QsTheme.shapes.cover)))
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Box(Modifier.widthIn(max = 180.dp).fillMaxWidth().size(180.dp, 12.dp).background(c.disabledBg, CircleShape))
            Box(Modifier.size(120.dp, 10.dp).background(c.disabledBg, CircleShape))
        }
    }
}
