package app.quietreading.feature.stats

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonSize
import app.quietreading.designsystem.components.QsSegmented
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.roundToInt

/** Flow 8b › Reading stamps. "Collect, don't compete. Stamps never expire and nothing resets." */
@Composable
fun StampsScreen(nav: AppNav) {
    val c = QsTheme.colors
    val books = rememberBooks()
    val stats = remember(books) { ReadingStats(books) }
    val (joined, setJoined) = rememberPref(StatsKeys.joined, false)
    val challenge = remember(stats) { SeasonalChallenge.of(stats) }
    val stamps = remember(stats, joined) { Stamp.all(stats, joined && (challenge?.done ?: false)) }
    var detail by remember { mutableStateOf<Stamp?>(null) }
    var showJoin by remember { mutableStateOf(false) }

    FlowScreen("Reading stamps", onBack = nav::back, backLabel = "Stats") {
        Text("Collect, don’t compete. Stamps never expire and nothing resets.", style = QsType.subheadline, color = c.ink2)
        StatsCard(
            "Reading stamps",
            summary = "Stamps are kept forever. Tap a locked one to see how to get it.",
            trailing = { Text("${stamps.count { it.earned }} of ${stamps.size}", style = QsType.caption, color = c.ink2) },
        ) { StampGrid(stamps) { detail = it } }
        if (challenge != null) ChallengeCard(challenge, joined) { showJoin = true }
    }
    detail?.let { StampDetailSheet(it) { detail = null } }
    if (showJoin && challenge != null) JoinChallengeSheet(challenge, joined, onDismiss = { showJoin = false }) { setJoined(it); showJoin = false }
}

/** Flow 8 › Your 2026 in books: covers, a few numbers, the favourite, and a card made to share. */
@Composable
fun YearInBooksScreen(nav: AppNav, year: Int) {
    val c = QsTheme.colors
    val app = LocalApp.current
    val context = LocalContext.current
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    val books = rememberBooks()
    val stats = remember(books) { ReadingStats(books) }
    val finished = stats.finished(year)
    val (name, _) = rememberPref(Keys.name, "")
    val theme = QsTheme.id
    val line = "${finished.size} books · ${stats.pages(year).grouped()} pages · ${stats.newAuthors(year)} new authors"
    val title = if (name.isBlank()) "I read ${finished.size} books in $year" else "$name read ${finished.size} books in $year"

    FlowScreen(
        "Your $year in books", onBack = nav::back, backLabel = "Stats",
        actions = if (finished.isEmpty()) null else ({
            QsButton("Share", {
                scope.launch {
                    val file = StatsShareCard.file(context, app.covers, finished.takeLast(3), title, line, theme)
                    if (file != null) StatsShareCard.share(context, file, "My $year in books")
                    else notifier.show("The image isn’t ready", "Try sharing again in a moment.", kind = NoticeKind.Error)
                }
            })
        }),
    ) {
        Text(line, style = QsType.subheadline, color = c.ink2)
        if (finished.isEmpty()) {
            EmptyState(R.drawable.ic_qs_calendar, "Your year is still being written", "Books you finish this year gather here, ready to share.", Modifier.padding(top = QsSpace.s40))
        }
        finished.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                row.forEach { b ->
                    Box(Modifier.weight(1f).pressable(label = b.title) { nav.openBook(b.id) }.semantics { contentDescription = b.title }) {
                        BookCover(b.coverFile, b.title, width = null)
                    }
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        stats.favourite(year)?.let { fav ->
            val shape = RoundedCornerShape(QsTheme.shapes.card)
            val stars = fav.score.takeIf { it > 0 }?.let { "★ ${it.oneDecimal()}" }
            val mood = stats.topMood(year)?.let { "most felt: $it" }
            Row(
                Modifier.fillMaxWidth().clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape)
                    .pressable(label = "Open ${fav.title}") { nav.openBook(fav.id) }.semantics(mergeDescendants = true) {}.padding(QsSpace.s12),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
            ) {
                BookCover(fav.coverFile, fav.title, width = QsSize.coverS)
                Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
                    Text("FAVOURITE", style = QsType.caption2.semibold(), color = c.ink2)
                    Text(fav.title, style = QsTheme.headline(18), color = c.ink)
                    Text(listOfNotNull(stars, mood).joinToString(" · "), style = QsType.footnote, color = c.ink2)
                }
            }
        }
    }
}

/**
 * Flow 8b › Patterns (Plus): moods, pace, time of day, ratings, this year vs last year.
 * Free readers see a soft preview with one calm way in. Basic stats stay free.
 */
@Composable
fun PatternsScreen(nav: AppNav) {
    val c = QsTheme.colors
    val app = LocalApp.current
    val notifier = LocalNotifier.current
    val books = rememberBooks()
    val stats = remember(books) { ReadingStats(books) }
    val plus by app.prefs.flow(Keys.plusUnlocked, false).collectAsState(initial = false)
    var range by rememberSaveable { mutableStateOf(ReadingStats.Range.Year) }

    FlowScreen("Patterns", onBack = nav::back, backLabel = "Stats") {
        QsSegmented(ReadingStats.Range.entries.map { it to it.title }, range) { range = it }
        Box {
            Column(
                Modifier.then(if (plus) Modifier else Modifier.blur(6.dp).clearAndSetSemantics {}),
                verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
            ) {
                MoodsCard(stats, range)
                PaceCard(stats)
                TimeOfDayCard(stats, range)
                RatingsCard(stats, range)
                YearVsYearCard(stats)
            }
            if (!plus) {
                // Locked: a blurred preview with one calm way in (the charts aren't interactive).
                Column(
                    Modifier.padding(top = QsSpace.s48).fillMaxWidth()
                        .shadow(12.dp, RoundedCornerShape(QsTheme.shapes.card), ambientColor = c.scrim.copy(alpha = 0.12f), spotColor = c.scrim.copy(alpha = 0.12f))
                        .background(c.surface, RoundedCornerShape(QsTheme.shapes.card)).padding(QsSpace.s24),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
                ) {
                    Text("Your patterns live in Plus", style = QsTheme.headline(22), color = c.ink, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
                    Text("Moods, pace, when you read, ratings and year vs year. Basic stats stay free.", style = QsType.subheadline, color = c.ink2, textAlign = TextAlign.Center)
                    QsButton("See Plus", {
                        // The paywall route is added with Flow 5; until then say so calmly.
                        if (nav.controller.graph.findNode("plus") != null) nav.controller.navigate("plus")
                        else notifier.show("Plus is coming to Android", "Your basic stats stay free.", kind = NoticeKind.Info)
                    }, Modifier.width(180.dp), size = QsButtonSize.Small)
                }
            }
        }
    }
}

private fun moodColors(c: app.quietreading.designsystem.QsColors) = listOf(c.accent, c.chart2, c.chart3, c.chart4, c.tintStrong)

@Composable
private fun MoodsCard(stats: ReadingStats, range: ReadingStats.Range) {
    val c = QsTheme.colors
    val data = stats.moods(range).take(5)
    val total = max(1, data.sumOf { it.value })
    val colors = moodColors(c)
    val summary = if (data.isEmpty()) "Add moods when you finish a book and they gather here."
    else "Mostly ${data[0].name.lowercase()} (${percent(data[0].value, total)}%) ${range.phrase}."
    StatsCard("Moods", summary = summary, trailing = { PlusPill() }) {
        if (data.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s20)) {
                Box(Modifier.size(QsSpace.s80 + QsSpace.s20).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
                    Canvas(Modifier.size(QsSpace.s80 + QsSpace.s20)) {
                        val stroke = size.minDimension * 0.19f
                        var start = -90f
                        data.forEachIndexed { i, m ->
                            val sweep = 360f * m.value / total
                            drawArc(colors[i % colors.size], start + 0.75f, sweep - 1.5f, false,
                                topLeft = Offset(stroke / 2, stroke / 2), size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke), style = Stroke(stroke))
                            start += sweep
                        }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${percent(data[0].value, total)}%", style = QsTheme.headline(18), color = c.ink)
                        Text(data[0].name, style = QsType.caption2, color = c.ink2)
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s6)) {
                    data.forEachIndexed { i, m ->
                        Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s6)) {
                            Box(Modifier.size(QsSpace.s8).background(colors[i % colors.size], RoundedCornerShape(2.dp)))
                            Text(m.name, style = QsType.caption, color = c.ink, modifier = Modifier.weight(1f))
                            Text("${percent(m.value, total)}%", style = QsType.caption, color = c.ink2)
                        }
                    }
                }
            }
        }
    }
}

/** A small line/area chart drawn on a canvas (pace, year vs year). */
@Composable
private fun LineChart(series: List<Triple<List<Double>, androidx.compose.ui.graphics.Color, Boolean>>, xCount: Int, fillFirst: Boolean, labels: List<Pair<Int, String>>) {
    val c = QsTheme.colors
    val maxY = max(1.0, series.flatMap { it.first }.maxOrNull() ?: 1.0)
    val anim = remember { Animatable(0f) }
    val reduce = QsTheme.reduceMotion
    LaunchedEffect(series.map { it.first }) { anim.snapTo(if (reduce) 1f else 0f); anim.animateTo(1f, tween(if (reduce) 0 else QsMotion.slow * 2)) }
    Column(Modifier.clearAndSetSemantics {}) {
        Canvas(Modifier.fillMaxWidth().height(QsSpace.s80 * 1.4f)) {
            val w = size.width
            val h = size.height
            for (g in 0..2) drawLine(c.line, Offset(0f, h * g / 2f), Offset(w, h * g / 2f), 1.dp.toPx())
            series.forEachIndexed { si, (values, color, dashed) ->
                if (values.isEmpty()) return@forEachIndexed
                val step = if (xCount > 1) w / (xCount - 1) else w
                val pts = values.mapIndexed { i, v -> Offset(i * step, (h - (v / maxY * h * anim.value)).toFloat()) }
                val path = Path().apply { pts.forEachIndexed { i, p -> if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) } }
                if (fillFirst && si == 0) {
                    val area = Path().apply { addPath(path); lineTo(pts.last().x, h); lineTo(pts.first().x, h); close() }
                    drawPath(area, c.chart4)
                }
                drawPath(path, color, style = Stroke(if (dashed) 2.dp.toPx() else 2.5.dp.toPx(),
                    pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx())) else null))
            }
        }
        Box(Modifier.fillMaxWidth().padding(top = QsSpace.s4)) {
            labels.forEach { (i, t) ->
                val align = when { i == 0 -> Alignment.CenterStart; i >= xCount - 1 -> Alignment.CenterEnd; else -> Alignment.Center }
                Text(t, style = QsType.caption2, color = c.ink2, modifier = Modifier.align(align))
            }
        }
    }
}

@Composable
private fun PaceCard(stats: ReadingStats) {
    val c = QsTheme.colors
    val data = stats.pace()
    val last = data.lastOrNull()?.perDay ?: 0.0
    val first = data.firstOrNull()?.perDay ?: 0.0
    StatsCard(
        "Reading pace",
        summary = "Average ${last.roundToInt()} pages a day this week, ${first.roundToInt()} twelve weeks ago.",
        trailing = {
            Text("${last.roundToInt()} p/day", style = QsType.caption2.semibold(), color = c.onAccent,
                modifier = Modifier.background(c.accent, CircleShape).padding(horizontal = QsSpace.s6, vertical = QsSpace.s2))
            PlusPill()
        },
    ) {
        val labels = data.mapIndexedNotNull { i, w -> if (i == 0 || i == data.size - 1 || i == data.size / 2) i to "${w.start.dayOfMonth} ${w.start.month.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.getDefault())}" else null }
        LineChart(listOf(Triple(data.map { it.perDay }, c.accent, false)), data.size, fillFirst = true, labels = labels)
    }
}

@Composable
private fun TimeOfDayCard(stats: ReadingStats, range: ReadingStats.Range) {
    val c = QsTheme.colors
    val data = stats.timeOfDay(range)
    val total = max(1, data.sumOf { it.value })
    val top = data.maxByOrNull { it.value }
    val summary = if ((top?.value ?: 0) > 0) "Mostly in the ${top!!.name.lowercase()}." else "Update your page now and then, and your reading times show up here."
    StatsCard("When you read", summary = summary, trailing = { PlusPill() }) {
        data.forEach { item ->
            val share = item.value.toFloat() / total
            val isTop = item == top && item.value > 0
            Row(
                Modifier.clearAndSetSemantics { contentDescription = item.name; stateDescription = "${(share * 100).roundToInt()}%" },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
            ) {
                Text(item.name, style = QsType.caption, color = c.ink, modifier = Modifier.width(QsSpace.s80))
                Box(Modifier.weight(1f).height(QsSpace.s8).clip(CircleShape).background(c.chartTrack)) {
                    if (share > 0) Box(Modifier.fillMaxWidth(share).height(QsSpace.s8).clip(CircleShape).background(if (isTop) c.accent else c.chart3))
                }
                Text("${(share * 100).roundToInt()}%", style = QsType.caption.copy(fontWeight = if (isTop) FontWeight.SemiBold else FontWeight.Normal), color = c.ink,
                    textAlign = TextAlign.End, modifier = Modifier.width(QsSpace.s40))
            }
        }
    }
}

@Composable
private fun RatingsCard(stats: ReadingStats, range: ReadingStats.Range) {
    val data = stats.ratings(range)
    val top = data.maxByOrNull { it.second }
    val summary = if ((top?.second ?: 0) > 0) "Most books get ${starLabel(top!!.first)} stars." else "Rate a book when you finish it and your ratings gather here."
    StatsCard("Your ratings", summary = summary, trailing = { PlusPill() }) {
        BarChart(
            data.map { it.second }, data.map { starLabel(it.first) }, data.map { "${starLabel(it.first)} stars" }, "books",
            data.indexOf(top).takeIf { (top?.second ?: 0) > 0 }, height = QsSpace.s80 * 1.2f,
        )
    }
}

@Composable
private fun YearVsYearCard(stats: ReadingStats) {
    val c = QsTheme.colors
    val y = stats.currentYear
    val now = stats.cumulative(y)
    val before = stats.cumulative(y - 1)
    val so = now.lastOrNull() ?: 0
    val last = if (before.size >= now.size) before[max(0, now.size - 1)] else (before.lastOrNull() ?: 0)
    val diff = so - last
    val summary = when {
        diff == 0 -> "$so books so far – the same as this time last year."
        diff > 0 -> "$so books so far – $diff more than this time last year."
        else -> "$so books so far – ${-diff} fewer than this time last year. Every year reads differently."
    }
    StatsCard("$y vs ${y - 1}", summary = summary, trailing = { PlusPill() }) {
        LineChart(
            listOf(Triple(now.map { it.toDouble() }, c.accent, false), Triple(before.map { it.toDouble() }, c.chart2, true)),
            12, fillFirst = false, labels = listOf(0 to monthShort(0), 5 to monthShort(5), 11 to monthShort(11)),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            LegendLine(c.accent, false, "$y · $so books")
            LegendLine(c.chart2, true, "${y - 1} · ${before.lastOrNull() ?: 0} books")
        }
    }
}
