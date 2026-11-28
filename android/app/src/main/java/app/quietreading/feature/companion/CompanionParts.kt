package app.quietreading.feature.companion

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.quietreading.R
import app.quietreading.designsystem.QsColors
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.sin

/**
 * 🧱 Components › AI button. Floating (phone, 56 dp, bottom-right above the tab bar, Elevation/2)
 * or docked in the rail (48 dp). One soft "breath" when it appears, so it's noticed without nagging.
 */
@Composable
fun CompanionButton(size: Dp = 56.dp, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = QsTheme.colors
    val reduce = QsTheme.reduceMotion
    val glow = remember { Animatable(1f) }
    LaunchedEffect(Unit) {
        if (reduce) return@LaunchedEffect
        repeat(2) {
            glow.animateTo(1.06f, tween(QsMotion.slow))
            glow.animateTo(1f, tween(QsMotion.slow))
        }
    }
    Box(
        modifier
            .size(size)
            .shadow(8.dp, CircleShape, ambientColor = c.scrim.copy(alpha = 0.10f), spotColor = c.scrim.copy(alpha = 0.10f))
            .clip(CircleShape)
            .background(c.ai)
            .pressable(label = "Chat about your books", onClick = onClick)
            .semantics { contentDescription = "Astrid, your reading companion" },
        contentAlignment = Alignment.Center,
    ) {
        QsIcon(R.drawable.ic_qs_sparkles, Modifier.scale(glow.value), tint = c.onAi, size = QsSize.iconL)
    }
}

/** 32 dp sparkle avatar in front of Astrid's turns. */
@Composable
fun CompanionAvatar() {
    val c = QsTheme.colors
    Box(Modifier.size(QsSpace.s32).background(c.aiSoft, CircleShape).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
        QsIcon(R.drawable.ic_qs_sparkles, tint = c.aiInk, size = QsSize.iconS)
    }
}

/** "Astrid · AI" header pill. */
@Composable
fun AiPill(text: String = "AI") {
    val c = QsTheme.colors
    Text(
        text, style = QsType.caption2.semibold(), color = c.aiInk,
        modifier = Modifier.background(c.aiSoft, CircleShape).padding(horizontal = QsSpace.s6, vertical = QsSpace.s2)
            .semantics { contentDescription = if (text == "AI") "A I" else text },
    )
}

// AI text formatting

private sealed interface Block {
    data class Paragraph(val text: String) : Block
    data class Items(val items: List<String>, val numbered: Boolean) : Block
}

private fun blocks(text: String): List<Block> {
    val out = mutableListOf<Block>()
    val para = mutableListOf<String>()
    val list = mutableListOf<String>()
    var numbered = false
    fun flushPara() { if (para.isNotEmpty()) { out += Block.Paragraph(para.joinToString(" ")); para.clear() } }
    fun flushList() { if (list.isNotEmpty()) { out += Block.Items(list.toList(), numbered); list.clear() } }
    val step = Regex("^\\d+\\.\\s")
    for (raw in text.split("\n")) {
        val l = raw.trim()
        when {
            l.isEmpty() -> { flushPara(); flushList() }
            l.startsWith("- ") || l.startsWith("• ") -> { flushPara(); if (numbered) flushList(); numbered = false; list += l.drop(2) }
            step.containsMatchIn(l) -> { flushPara(); if (!numbered) flushList(); numbered = true; list += l.replaceFirst(step, "") }
            else -> { flushList(); para += l }
        }
    }
    flushPara(); flushList()
    return out
}

/**
 * **bold** → semibold; *Title* → heading serif italic in accentInk, underlined and tappable when it's on the shelf.
 * Everything else is plain text (raw links never become links).
 */
fun inline(s: String, c: QsColors, serif: androidx.compose.ui.text.font.FontFamily, linkable: (String) -> Boolean, onTitle: (String) -> Unit): AnnotatedString = buildAnnotatedString {
    var i = 0
    while (i < s.length) {
        if (s.startsWith("**", i)) {
            val end = s.indexOf("**", i + 2)
            if (end > i + 2) {
                withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(s.substring(i + 2, end)) }
                i = end + 2; continue
            }
        }
        if (s[i] == '*' || (s[i] == '_' && (i == 0 || !s[i - 1].isLetterOrDigit()))) {
            val mark = s[i]
            val end = s.indexOf(mark, i + 1)
            if (end > i + 1 && !s.substring(i + 1, end).contains('\n')) {
                val title = s.substring(i + 1, end)
                val style = SpanStyle(fontFamily = serif, fontStyle = FontStyle.Italic, color = c.accentInk, fontSize = 17.sp)
                if (linkable(title)) {
                    withLink(LinkAnnotation.Clickable("book", TextLinkStyles(style.copy(textDecoration = TextDecoration.Underline))) { onTitle(title) }) { append(title) }
                } else {
                    withStyle(style) { append(title) }
                }
                i = end + 1; continue
            }
        }
        append(s[i]); i++
    }
}

/** Plain text for TalkBack and Copy. */
fun plain(s: String) = s.replace("**", "").replace("*", "")

/** A companion turn: avatar and text on the page background (no bubble). Renders the allowed Markdown subset. */
@Composable
fun CompanionMessageRow(text: String, linkable: (String) -> Boolean = { false }, onTitle: (String) -> Unit = {}) {
    val c = QsTheme.colors
    val serif = QsTheme.headFamily
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) { contentDescription = "Astrid: " + plain(text) },
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        CompanionAvatar()
        Column(Modifier.weight(1f).padding(top = QsSpace.s6), verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            val style = QsType.subheadline.copy(lineHeight = 21.sp, color = c.ink)
            for (b in blocks(text)) when (b) {
                is Block.Paragraph -> Text(inline(b.text, c, serif, linkable, onTitle), style = style)
                is Block.Items -> Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                    b.items.forEachIndexed { i, item ->
                        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                            Text(if (b.numbered) "${i + 1}." else "•", style = style, modifier = Modifier.clearAndSetSemantics {})
                            Text(inline(item, c, serif, linkable, onTitle), style = style)
                        }
                    }
                }
            }
        }
    }
}

/**
 * The companion "breathes" while it thinks: the sparkle avatar glows and turns a little,
 * three dots rise and fall in a soft wave. After 8 s: "Still thinking…" with Stop.
 * Reduce Motion: still dots and the words "Thinking…".
 */
@Composable
fun ThinkingIndicator(onStop: () -> Unit) {
    val c = QsTheme.colors
    val reduce = QsTheme.reduceMotion
    var slow by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(8_000); slow = true }
    val t by rememberInfiniteTransition(label = "thinking").animateFloat(
        0f, (2 * PI).toFloat(), infiniteRepeatable(tween(2_800, easing = LinearEasing), RepeatMode.Restart), label = "t",
    )
    Column(Modifier.semantics(mergeDescendants = true) { contentDescription = "Astrid is thinking" }, verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            val breath = if (reduce) 0f else (sin(t * 2) + 1) / 2
            Box(Modifier.size(QsSpace.s32), contentAlignment = Alignment.Center) {
                Box(Modifier.size(QsSpace.s32).background(c.aiSoft, CircleShape))
                Box(Modifier.size(QsSpace.s32).scale(1 + 0.25f * breath).blur(4.dp).background(c.ai.copy(alpha = 0.25f * breath), CircleShape))
                QsIcon(R.drawable.ic_qs_sparkles, Modifier.rotate(if (reduce) 0f else sin(t) * 12f).scale(1 + 0.08f * breath), tint = c.aiInk, size = QsSize.iconS)
            }
            if (reduce) {
                Text("Thinking…", style = QsType.subheadline, color = c.ink2)
            } else {
                Row(
                    Modifier.heightIn(min = QsSpace.s32).background(c.surface, CircleShape).border(QsSize.stroke, c.line, CircleShape).padding(horizontal = QsSpace.s12),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(QsSpace.s6),
                ) {
                    repeat(3) { i ->
                        val wave = (sin(t * 3 - i * 0.9f) + 1) / 2
                        Box(Modifier.offset(y = (-4 * wave).dp).size(QsSpace.s8).alpha(0.35f + 0.65f * wave).background(c.ai, CircleShape))
                    }
                }
            }
        }
        AnimatedVisibility(slow, enter = fadeIn(tween(QsMotion.base))) {
            Row(Modifier.padding(start = QsSpace.s40), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                Text("Still thinking…", style = QsType.footnote, color = c.ink2)
                Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(onClick = onStop).padding(horizontal = QsSpace.s8), contentAlignment = Alignment.Center) {
                    Text("Stop", style = QsType.footnote.semibold(), color = c.accentInk)
                }
            }
        }
    }
}

/** Bullet box on the consent screen ("What it can see"). */
@Composable
fun BulletBox(title: String, items: List<String>, fill: androidx.compose.ui.graphics.Color) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        Modifier.fillMaxWidth().background(fill, shape).border(QsSize.stroke, c.line, shape).padding(QsSpace.s16).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Text(title, style = QsType.subheadline.semibold(), color = c.ink, modifier = Modifier.semantics { heading() })
        items.forEach { Text("•  $it", style = QsType.subheadline, color = c.ink) }
    }
}
