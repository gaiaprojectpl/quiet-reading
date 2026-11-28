package app.quietreading.feature.plus

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.data.Keys
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import app.quietreading.feature.add.rememberIsOnline
import app.quietreading.feature.settings.ThemeCard
import app.quietreading.feature.stats.QsSheet
import kotlinx.coroutines.launch

object PlusRoutes {
    const val PLUS = "plus"
}

/** Flow 5 · Plus themes & payment. */
fun NavGraphBuilder.plusGraph(nav: AppNav) {
    composable(PlusRoutes.PLUS) { PlusScreen(onClose = nav::back) }
}

private object PlusLinks {
    /** Google Play's terms (until Quiet Reading has its own). */
    const val TERMS = "https://play.google.com/about/play-terms/"
    /** Google Play handles refunds for Play purchases. */
    const val REFUNDS = "https://support.google.com/googleplay/answer/2479637"
}

private fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}

/**
 * Flow 5 › Paywall: "Make it yours". One payment, no subscription.
 * The price comes from Google Play; the buy button only shows once Play has answered.
 * Edge states: payment failed, nothing to restore, pending approval, offline, store not answering.
 */
@Composable
fun PlusScreen(onClose: () -> Unit) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val plus = remember { PlusAccess.get(context) }
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    val online = rememberIsOnline()
    val (_, setTheme) = rememberPref(Keys.theme, ThemeId.PeachSage.name)
    var pick by rememberSaveable { mutableStateOf(PlusPreview.theme?.takeIf { it.requiresPlus } ?: ThemeId.ClayCream) }
    var nothingToRestore by remember { mutableStateOf(false) }
    var showPrivacy by remember { mutableStateOf(false) }
    val store = plus.store

    fun showOffline() = notifier.show("You’re offline", "Connect to buy or restore Plus.", NoticeKind.Info)

    LaunchedEffect(Unit) {
        if (!online) showOffline()
        plus.loadProduct()
    }
    LaunchedEffect(online) { if (online && plus.store == PlusAccess.StoreState.Unavailable) plus.loadProduct() }

    fun buy() = scope.launch {
        if (!online) { showOffline(); return@launch }
        val activity = context.activity() ?: return@launch
        when (plus.purchase(activity)) {
            PlusAccess.PurchaseResult.Unlocked -> {
                setTheme(pick.name)
                PlusPreview.theme = null
                onClose()
                notifier.show("Plus unlocked", "${pick.displayName} is on. Thank you for supporting a small app.")
            }
            PlusAccess.PurchaseResult.Pending ->
                notifier.show("Waiting for approval", "Your purchase is pending. Plus unlocks when it’s approved.", NoticeKind.Info)
            PlusAccess.PurchaseResult.Failed ->
                notifier.show("Payment didn’t go through", "You weren’t charged. Check your payment method and try again.", NoticeKind.Error)
            PlusAccess.PurchaseResult.Cancelled -> Unit // the reader changed their mind; nothing to say
        }
    }

    fun restore() = scope.launch {
        if (!online) { showOffline(); return@launch }
        when (plus.restore()) {
            PlusAccess.RestoreResult.Restored -> {
                PlusPreview.theme = null
                onClose()
                notifier.show("Plus is back", "Your themes are ready in Settings.")
            }
            PlusAccess.RestoreResult.Nothing -> nothingToRestore = true
            PlusAccess.RestoreResult.Failed ->
                notifier.show("Couldn’t reach Google Play", "Nothing changed. Try again in a moment.", NoticeKind.Error)
        }
    }

    FlowScreen(
        title = null,
        topTrailing = { QsIconButton(R.drawable.ic_qs_close, "Close", tint = c.ink2, onClick = onClose) },
        actions = {
            when (store) {
                is PlusAccess.StoreState.Ready -> {
                    if (plus.isBusy) {
                        Box(Modifier.fillMaxWidth().heightIn(min = QsSize.button).background(c.accent, RoundedCornerShape(QsTheme.shapes.btn))
                            .semantics { contentDescription = "Waiting for Google Play" }, contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = c.onAccent, strokeWidth = 2.dp, modifier = Modifier.size(QsSize.iconL))
                        }
                    } else {
                        QsButton("Unlock Plus for ${store.price}", { buy() })
                    }
                    Links(enabled = !plus.isBusy, onRestore = { restore() }, onPrivacy = { showPrivacy = true })
                }
                PlusAccess.StoreState.Loading -> {
                    Box(Modifier.fillMaxWidth().height(QsSize.button).background(c.disabledBg, RoundedCornerShape(QsTheme.shapes.btn)))
                    Links(enabled = false, onRestore = {}, onPrivacy = { showPrivacy = true })
                }
                PlusAccess.StoreState.Unavailable -> {
                    QsButton("Try again", { scope.launch { plus.loadProduct() } })
                    QsButton("Not now", onClose, kind = QsButtonKind.Text)
                }
            }
        },
    ) {
        Header()
        if (store == PlusAccess.StoreState.Unavailable) {
            StoreNotAnswering()
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                listOf(ThemeId.ClayCream, ThemeId.BlushIvory, ThemeId.LavenderMist).forEach { id ->
                    ThemeCard(id, selected = pick == id, locked = false, modifier = Modifier.weight(1f)) { pick = id }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                Benefit(R.drawable.ic_qs_palette, "3 extra app themes")
                Benefit(R.drawable.ic_qs_widgets, "20+ widget styles: Soft, Modern, Colourful", soon = true)
                Benefit(R.drawable.ic_qs_stats, "Patterns: moods, pace, time of day")
                Benefit(R.drawable.ic_qs_pencil, "Stylus margin notes on foldables", soon = true)
            }
            PriceCard(store)
        }
    }

    if (nothingToRestore) {
        AlertDialog(
            onDismissRequest = { nothingToRestore = false },
            confirmButton = { TextButton({ nothingToRestore = false }) { Text("OK", color = c.accentInk) } },
            title = { Text("Nothing to restore", color = c.ink) },
            text = { Text("We couldn’t find Plus on this account. Make sure you’re signed in to Google Play with the account you used to buy it.", color = c.ink2) },
            containerColor = c.surface,
        )
    }
    if (showPrivacy) {
        QsSheet(onDismiss = { showPrivacy = false }, title = "Your privacy") {
            Text(
                "Your books, notes and quotes stay on this phone. Quiet Reading has no ads and no tracking. Google Play handles payment, so we never see your card.",
                style = QsType.body, color = c.ink2,
            )
            QsButton("Done", { showPrivacy = false }, kind = QsButtonKind.Secondary, modifier = Modifier.padding(bottom = QsSpace.s24))
        }
    }
}

@Composable
private fun Header() {
    val c = QsTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
            modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = "Quiet Reading Plus" },
        ) {
            Box(Modifier.size(QsSpace.s24).background(c.accent, RoundedCornerShape(QsSpace.s6)), contentAlignment = Alignment.Center) {
                Icon(painterResource(R.drawable.ic_qs_logo), null, tint = c.bg, modifier = Modifier.size(QsSpace.s24))
            }
            Text("Quiet Reading", style = QsTheme.headline(18), color = c.ink)
            QsIcon(R.drawable.ic_qs_crown, tint = c.accentInk, size = QsSize.iconS)
            Text("PLUS", style = QsType.caption.semibold().copy(letterSpacing = 1.sp), color = c.accentInk)
        }
        Text("Make it yours", style = QsTheme.headline(30), color = c.ink, modifier = Modifier.semantics { heading() })
        Text("One small payment. No subscription, no ads, ever.", style = QsType.body, color = c.ink2)
    }
}

@Composable
private fun Benefit(@DrawableRes icon: Int, text: String, soon: Boolean = false) {
    val c = QsTheme.colors
    Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
        Box(Modifier.size(QsSpace.s24).background(c.soft2, CircleShape), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = c.accentInk, size = QsSize.iconS)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(text, style = QsType.subheadline, color = c.ink)
            if (soon) Text("Coming soon, included", style = QsType.caption, color = c.ink2)
        }
    }
}

@Composable
private fun PriceCard(store: PlusAccess.StoreState) {
    val c = QsTheme.colors
    Column(
        Modifier.fillMaxWidth().background(c.soft, RoundedCornerShape(QsTheme.shapes.card)).padding(QsSpace.s16),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        val fadeMs = if (QsTheme.reduceMotion) 0 else QsMotion.base
        AnimatedContent(store is PlusAccess.StoreState.Ready, transitionSpec = {
            fadeIn(tween(fadeMs)) togetherWith fadeOut(tween(QsMotion.fast))
        }, label = "price") { ready ->
            if (ready && store is PlusAccess.StoreState.Ready) {
                Text("${store.price} · once", style = QsTheme.headline(22), color = c.ink)
            } else {
                // Skeleton while Google Play answers (no shimmer).
                Box(Modifier.width(QsSpace.s80 + QsSpace.s20).height(QsSpace.s24).background(c.disabledBg, RoundedCornerShape(QsTheme.shapes.inner))
                    .semantics { contentDescription = "Loading the price" })
            }
        }
        Text(
            "Price shown in your currency at checkout. One-time purchase for your Google account, not shared with family.",
            style = QsType.footnote, color = c.ink2,
        )
    }
}

/** Google Play didn't answer within 8 seconds (or isn't reachable, e.g. no Play on this device). */
@Composable
private fun StoreNotAnswering() {
    val c = QsTheme.colors
    Column(
        Modifier.fillMaxWidth().padding(top = QsSpace.s8).background(c.infoSoft, RoundedCornerShape(QsTheme.shapes.card)).padding(QsSpace.s16),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Text("The store isn’t answering", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
        Text("Plus can wait. Everything free still works, and you weren’t charged.", style = QsType.body, color = c.ink2)
    }
}

@Composable
private fun Links(enabled: Boolean, onRestore: () -> Unit, onPrivacy: () -> Unit) {
    val context = LocalContext.current
    fun open(url: String) = runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        LinkButton("Restore purchase", enabled, onRestore)
        LinkButton("Terms", enabled) { open(PlusLinks.TERMS) }
        LinkButton("Privacy", true, onPrivacy)
        LinkButton("Refunds", enabled) { open(PlusLinks.REFUNDS) }
    }
}

@Composable
private fun LinkButton(title: String, enabled: Boolean, onClick: () -> Unit) {
    val c = QsTheme.colors
    Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(enabled = enabled, onClick = onClick).padding(horizontal = QsSpace.s6), contentAlignment = Alignment.Center) {
        Text(title, style = QsType.footnote, color = if (enabled) c.ink2 else c.disabledInk)
    }
}

/**
 * Flow 5 › Live preview: "Previewing Clay & Cream · Get Plus", just above the navigation.
 * Shown while a Plus theme is being tried on without Plus.
 */
@Composable
fun PlusPreviewBar(onGetPlus: () -> Unit) {
    val c = QsTheme.colors
    val theme = PlusPreview.theme ?: return
    Row(
        Modifier.padding(horizontal = QsSpace.s16).padding(bottom = QsSpace.s8).fillMaxWidth()
            .background(c.inverse, RoundedCornerShape(QsTheme.shapes.card)).padding(start = QsSpace.s16, end = QsSpace.s4),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Text("Previewing ${theme.displayName}", style = QsType.subheadline.semibold(), color = c.onInverse, modifier = Modifier.weight(1f))
        Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(onClick = onGetPlus), contentAlignment = Alignment.Center) {
            Box(Modifier.heightIn(min = QsSize.buttonSmall - QsSpace.s8).background(c.accent, RoundedCornerShape(QsTheme.shapes.btn))
                .padding(horizontal = QsSpace.s12), contentAlignment = Alignment.Center) {
                Text("Get Plus", style = QsType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = c.onAccent)
            }
        }
        QsIconButton(R.drawable.ic_qs_close, "End preview", tint = c.onInverse) { PlusPreview.theme = null }
    }
}
