package app.quietreading.feature.stats

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.quietreading.R
import app.quietreading.data.Book
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.components.rememberCover
import app.quietreading.designsystem.semibold
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt

// 🧱 Components › Charts: one hue per theme, values on the chart, a one-line summary under each,
// and never colour alone (the current bar is also underlined and bold).

fun Int.grouped(): String = "%,d".format(Locale.getDefault(), this)
fun Double.oneDecimal(): String = if (this % 1.0 == 0.0) toInt().toString() else "%.1f".format(Locale.getDefault(), this)
fun LocalDate.weekdayNarrow(): String = dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault())
fun LocalDate.weekdayFull(): String = dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
fun YearMonth.monthName(): String = month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault())
fun monthName(index: Int): String = java.time.Month.of(index + 1).getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault())
fun monthShort(index: Int): String = java.time.Month.of(index + 1).getDisplayName(TextStyle.SHORT_STANDALONE, Locale.getDefault())
fun monthLetter(index: Int): String = java.time.Month.of(index + 1).getDisplayName(TextStyle.NARROW_STANDALONE, Locale.getDefault())

/** Card shell used by every chart: title, optional control on the right, content, one-line summary. */
@Composable
fun StatsCard(
    title: String,
    modifier: Modifier = Modifier,
    summary: String? = null,
    trailing: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        modifier.fillMaxWidth().clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape).padding(QsSpace.s16),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Text(title, style = QsType.subheadline.semibold(), color = c.ink, modifier = Modifier.weight(1f).semantics { heading() })
            trailing()
        }
        content()
        if (summary != null) Text(summary, style = QsType.footnote, color = c.ink2)
    }
}

/** Small outlined pill with a chevron ("2026 ⌄") that opens a menu. */
@Composable
fun <T> PeriodMenu(options: List<Pair<T, String>>, selection: T, label: String, onSelect: (T) -> Unit) {
    val c = QsTheme.colors
    var open by remember { mutableStateOf(false) }
    Box {
        Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(label = label) { open = true }, contentAlignment = Alignment.Center) {
            Row(
                Modifier.border(QsSize.stroke, c.line, CircleShape).padding(horizontal = QsSpace.s8, vertical = QsSpace.s4)
                    .semantics { contentDescription = "$label: ${options.firstOrNull { it.first == selection }?.second.orEmpty()}" },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s4),
            ) {
                Text(options.firstOrNull { it.first == selection }?.second.orEmpty(), style = QsType.caption, color = c.ink2)
                QsIcon(R.drawable.ic_qs_chevron, Modifier.rotate(90f), tint = c.ink2, size = QsSize.iconS - 4.dp)
            }
        }
        DropdownMenu(open, onDismissRequest = { open = false }, containerColor = c.surface) {
            options.forEach { (value, title) ->
                DropdownMenuItem(
                    text = { Text(title, style = QsType.body.copy(fontWeight = if (value == selection) FontWeight.SemiBold else FontWeight.Normal), color = c.ink) },
                    onClick = { onSelect(value); open = false },
                    leadingIcon = if (value == selection) ({ QsIcon(R.drawable.ic_qs_check, tint = c.accentInk, size = QsSize.iconS) }) else null,
                )
            }
        }
    }
}

/** "Plus" pill with a crown, for Plus-only charts. */
@Composable
fun PlusPill() {
    val c = QsTheme.colors
    Row(
        Modifier.background(c.soft, CircleShape).padding(horizontal = QsSpace.s6, vertical = QsSpace.s2).semantics(mergeDescendants = true) { contentDescription = "Plus" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s2),
    ) {
        QsIcon(R.drawable.ic_qs_crown, tint = c.accentInk, size = QsSize.iconS - 4.dp)
        Text("Plus", style = QsType.caption2.semibold(), color = c.accentInk)
    }
}

// Yearly goal

@Composable
fun GoalCard(goal: ReadingStats.Goal, year: Int, years: List<Int>, onYear: (Int) -> Unit, onEdit: () -> Unit) {
    val c = QsTheme.colors
    val reduce = QsTheme.reduceMotion
    val fraction = if (goal.goal > 0) minOf(1f, goal.done.toFloat() / goal.goal) else 0f
    val shown = remember { Animatable(0f) }
    LaunchedEffect(fraction) { shown.animateTo(fraction, tween(if (reduce) 0 else QsMotion.slow * 2)) }
    val summary = when {
        goal.goal <= 0 -> "${goal.done} books in $year. Set a goal if you'd like one."
        goal.left == 0 -> "${goal.done} of ${goal.goal} books. You reached your goal."
        year != LocalDate.now().year -> "${goal.done} of ${goal.goal} books."
        else -> "${goal.done} of ${goal.goal} books. ${goal.left} to go – on pace for ${goal.onPaceFor}. No rush."
    }
    StatsCard("Yearly goal", summary = summary, trailing = {
        PeriodMenu(years.map { it to it.toString() }, year, "Year", onYear)
    }) {
        Row(
            Modifier.fillMaxWidth().pressable(label = "Edit goal", onClick = onEdit).clearAndSetSemantics { contentDescription = "$summary Edit goal" },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(QsSpace.s20),
        ) {
            Box(Modifier.size(QsSize.coverM + QsSpace.s24), contentAlignment = Alignment.Center) {
                Canvas(Modifier.size(QsSize.coverM + QsSpace.s24).padding(QsSpace.s4)) {
                    val w = QsSpace.s8.toPx()
                    drawCircle(c.chartTrack, style = Stroke(w))
                    drawArc(c.accent, -90f, 360f * shown.value, false, style = Stroke(w, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${goal.done}", style = QsTheme.headline(30), color = c.ink)
                    Text(if (goal.goal > 0) "of ${goal.goal} books" else "books", style = QsType.caption2, color = c.ink2)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                if (goal.goal > 0) {
                    Text("${goal.percent}%", style = QsTheme.headline(22), color = c.ink)
                    Text("of your goal", style = QsType.footnote, color = c.ink2)
                } else {
                    Text("Set a goal", style = QsType.subheadline.semibold(), color = c.accentInk)
                }
                Text("≈ ${goal.perMonth.oneDecimal()} books a month", style = QsType.footnote, color = c.ink2)
            }
        }
    }
}

// Weekly rhythm

/** Flexible rhythm: any N days a week count. Rest days show a moon. Nothing ever breaks. */
@Composable
fun RhythmCard(week: List<ReadingStats.Day>, goalDays: Int, onGoalDays: (Int) -> Unit) {
    val c = QsTheme.colors
    val read = week.count { it.didRead }
    val today = LocalDate.now()
    StatsCard(
        "This week’s rhythm",
        summary = "Flexible: any $goalDays days count. Rest days show a moon, never a broken streak.",
        trailing = { PeriodMenu((1..7).map { it to "Goal: $it days" }, goalDays, "Weekly goal", onGoalDays) },
    ) {
        Row(Modifier.fillMaxWidth()) {
            week.forEach { day ->
                val isToday = day.date == today
                Column(
                    Modifier.weight(1f).clearAndSetSemantics {
                        contentDescription = day.date.weekdayFull()
                        stateDescription = if (day.didRead) "Read" else "Rest day"
                    },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(QsSpace.s4),
                ) {
                    Box(
                        Modifier.size(QsSpace.s32 + QsSpace.s4)
                            .then(if (isToday) Modifier.border(QsSize.stroke, c.ink, CircleShape) else Modifier)
                            .padding(QsSpace.s2),
                        contentAlignment = Alignment.Center,
                    ) {
                        when {
                            day.didRead -> Box(Modifier.size(QsSpace.s32).background(c.accent, CircleShape), contentAlignment = Alignment.Center) {
                                QsIcon(R.drawable.ic_qs_check, tint = c.onAccent, size = QsSize.iconS)
                            }
                            day.date.isAfter(today) -> Box(Modifier.size(QsSpace.s32).border(QsSize.stroke, c.line, CircleShape))
                            else -> QsIcon(R.drawable.ic_qs_moon, tint = c.ink2, size = QsSize.iconS)
                        }
                    }
                    Text(day.date.weekdayNarrow(), style = QsType.caption2, color = c.ink2)
                }
            }
        }
        Text(
            if (read >= goalDays) "$read of $goalDays days – done for the week" else "$read of $goalDays days so far",
            style = QsTheme.headline(18), color = c.ink,
        )
    }
}

/**
 * Simple bar chart: values written above each bar, the highlighted bar in accent and its label bold + underlined
 * (never colour alone). Each bar is read by TalkBack as "label, value".
 */
@Composable
fun BarChart(values: List<Int>, labels: List<String>, spoken: List<String>, unit: String, highlight: Int?, height: Dp = QsSpace.s80 * 1.6f, barRatio: Float = 0.5f) {
    val c = QsTheme.colors
    val top = max(1, values.maxOrNull() ?: 1)
    val anim = remember { Animatable(0f) }
    val reduce = QsTheme.reduceMotion
    LaunchedEffect(values) { anim.snapTo(if (reduce) 1f else 0f); anim.animateTo(1f, tween(if (reduce) 0 else QsMotion.slow)) }
    Row(Modifier.fillMaxWidth().height(height + QsSpace.s32), verticalAlignment = Alignment.Bottom) {
        values.forEachIndexed { i, v ->
            val hi = i == highlight
            Column(
                Modifier.weight(1f).fillMaxHeight().clearAndSetSemantics { contentDescription = "${spoken[i]}, $v $unit" },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom,
            ) {
                if (v > 0) Text("$v", style = QsType.caption2.copy(fontWeight = if (hi) FontWeight.SemiBold else FontWeight.Normal), color = c.ink, maxLines = 1)
                Spacer(Modifier.height(QsSpace.s2))
                Box(
                    Modifier.fillMaxWidth(barRatio).height(height * (v.toFloat() / top) * anim.value)
                        .clip(RoundedCornerShape(50)).background(if (hi) c.accent else c.chart3),
                )
                Spacer(Modifier.height(QsSpace.s4))
                Text(
                    labels[i],
                    style = QsType.caption2.copy(fontWeight = if (hi) FontWeight.Bold else FontWeight.Normal, textDecoration = if (hi) TextDecoration.Underline else null),
                    color = c.ink2, maxLines = 1,
                )
            }
        }
    }
}

@Composable
fun PagesWeekCard(week: List<ReadingStats.Day>) {
    val today = LocalDate.now()
    val total = week.sumOf { it.pages }
    val todayPages = week.firstOrNull { it.date == today }?.pages ?: 0
    StatsCard("Pages this week", summary = "$total pages this week. Today: $todayPages pages.") {
        BarChart(
            week.map { it.pages }, week.map { it.date.weekdayNarrow() }, week.map { it.date.weekdayFull() }, "pages",
            week.indexOfFirst { it.date == today }.takeIf { it >= 0 }, barRatio = 0.45f,
        )
    }
}

// Reading days (calendar)

@Composable
fun ReadingDaysCard(stats: ReadingStats, month: YearMonth, onMonth: (YearMonth) -> Unit) {
    val c = QsTheme.colors
    val days = stats.days(month)
    val today = LocalDate.now()
    val months = (0L until 12L).map { YearMonth.now().minusMonths(it) }
    val fill = { l: ReadingStats.Level -> when (l) { ReadingStats.Level.Rest -> c.surface; ReadingStats.Level.Little -> c.chart4; ReadingStats.Level.More -> c.chart2; ReadingStats.Level.Lots -> c.accent } }
    val ink = { l: ReadingStats.Level -> if (l == ReadingStats.Level.Lots || l == ReadingStats.Level.More) c.onAccent else c.ink }
    val lead = ((month.atDay(1).dayOfWeek.value - stats.firstDayOfWeek.value) + 7) % 7
    StatsCard(
        "Reading days",
        summary = "You read on ${days.count { it.didRead }} days in ${month.monthName()}. Rest days are part of reading too.",
        trailing = { PeriodMenu(months.map { it to it.monthName() }, month, "Month", onMonth) },
    ) {
        val cells: List<ReadingStats.Day?> = List(lead) { null } + days
        val weekStart = stats.firstDayOfWeek
        Row(Modifier.fillMaxWidth().clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(QsSpace.s6)) {
            (0L until 7L).forEach { i ->
                Text(weekStart.plus(i).getDisplayName(TextStyle.NARROW_STANDALONE, Locale.getDefault()), style = QsType.caption2, color = c.ink2,
                    textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
        }
        cells.chunked(7).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(QsSpace.s6)) {
                (0 until 7).forEach { i ->
                    val day = row.getOrNull(i)
                    if (day == null) Spacer(Modifier.weight(1f)) else {
                        val level = if (day.didRead) ReadingStats.level(day.pages) else ReadingStats.Level.Rest
                        val isToday = day.date == today
                        val shape = RoundedCornerShape(QsTheme.shapes.inner - 2.dp)
                        Box(
                            Modifier.weight(1f).heightIn(min = QsSpace.s24 + QsSpace.s4).clip(shape).background(fill(level))
                                .border(if (isToday) QsSize.focusRing else 0.dp, if (isToday) c.ink else Color.Transparent, shape)
                                .clearAndSetSemantics {
                                    contentDescription = "${day.date.weekdayFull()} ${day.date.dayOfMonth} ${month.monthName()}"
                                    stateDescription = if (day.didRead) "${day.pages} pages" else "Rest day"
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("${day.date.dayOfMonth}", style = QsType.caption2.copy(fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal), color = ink(level))
                        }
                    }
                }
            }
        }
        Row(Modifier.clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            listOf(ReadingStats.Level.Rest to "Rest", ReadingStats.Level.Little to "A little", ReadingStats.Level.More to "More", ReadingStats.Level.Lots to "Lots").forEach { (l, t) ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                    Box(Modifier.size(QsSpace.s12).background(fill(l), RoundedCornerShape(QsSpace.s2)).border(QsSize.stroke, c.line, RoundedCornerShape(QsSpace.s2)))
                    Text(t, style = QsType.caption2, color = c.ink2)
                }
            }
        }
    }
}

// Books per month

@Composable
fun BooksPerMonthCard(counts: List<Int>, year: Int, years: List<Int>, onYear: (Int) -> Unit) {
    val current = if (year == LocalDate.now().year) LocalDate.now().monthValue - 1 else null
    val busiest = counts.withIndex().maxByOrNull { it.value }
    val parts = buildList {
        if (current != null) add("${monthName(current)}: ${counts[current]} books so far.")
        if (busiest != null && busiest.value > 0) add("Busiest month: ${monthName(busiest.index)}, ${busiest.value} books.")
    }
    StatsCard(
        "Books per month",
        summary = if (parts.isEmpty()) "No finished books in $year yet." else parts.joinToString(" "),
        trailing = { PeriodMenu(years.map { it to it.toString() }, year, "Year", onYear) },
    ) {
        BarChart(counts, (0 until 12).map(::monthLetter), (0 until 12).map(::monthName), "books", current)
    }
}

// Shelf of spines

/** Every finished book adds a spine in its cover colour. Tap a spine to open the book. */
@Composable
fun ShelfCard(books: List<Book>, year: Int, onOpen: (Book) -> Unit) {
    val c = QsTheme.colors
    val shelf = QsSpace.s80 + QsSpace.s20
    StatsCard(
        "Your $year shelf",
        summary = "Every finished book adds a spine in its cover colour. Tap a spine to open the book.",
        trailing = { Text("${books.size} books", style = QsType.caption, color = c.ink2) },
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth().height(shelf).horizontalScroll(rememberScrollState()).padding(horizontal = QsSpace.s8),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s2),
            ) {
                books.forEachIndexed { i, book ->
                    val cover = rememberCover(book.coverFile)
                    val colour = SpineColor.of(book.coverFile, cover?.asAndroidBitmap()) ?: if (i % 2 == 0) c.chart2 else c.tintStrong
                    val width = ((book.pageCount ?: 300) / 28f).coerceIn(12f, 22f).dp
                    Box(
                        Modifier.width(maxOf(width, 12.dp)).fillMaxHeight().pressable(label = "Open ${book.title}") { onOpen(book) }
                            .semantics { contentDescription = book.title },
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        Box(
                            Modifier.fillMaxWidth().fillMaxHeight(0.72f + 0.28f * ((i * 37) % 10) / 10f)
                                .rotate(if (i % 7 == 4) -6f else 0f)
                                .clip(RoundedCornerShape(2.dp)).background(colour)
                                .border(QsSize.stroke, c.ink.copy(alpha = 0.12f), RoundedCornerShape(2.dp)),
                        )
                    }
                }
            }
            // Wooden plank. No "wood" token in Figma yet, so it uses the warm theme roles.
            Box(Modifier.fillMaxWidth().height(QsSpace.s8).clip(RoundedCornerShape(2.dp)).background(Brush.verticalGradient(listOf(c.tintStrong, c.warning))))
        }
    }
}

// Stamps

/** One stamp: a soft circle with its icon. Earned = filled soft with accent ink; locked = dashed outline. */
@Composable
fun StampBadge(stamp: Stamp, modifier: Modifier = Modifier, size: Dp = QsSpace.s48) {
    val c = QsTheme.colors
    Column(
        modifier.clearAndSetSemantics {
            contentDescription = stamp.name
            stateDescription = if (stamp.earned) "Collected" else "Not yet. ${stamp.how}"
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        Box(Modifier.size(size), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(size)) {
                val dash = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))
                if (stamp.earned) {
                    drawCircle(c.soft)
                    drawCircle(c.accentInk.copy(alpha = 0.6f), radius = this.size.minDimension / 2 - 2.5.dp.toPx(), style = Stroke(1.dp.toPx(), pathEffect = dash))
                } else {
                    drawCircle(c.lineStrong.copy(alpha = 0.6f), radius = this.size.minDimension / 2 - 0.5.dp.toPx(), style = Stroke(1.dp.toPx(), pathEffect = dash))
                }
            }
            QsIcon(stamp.icon, tint = if (stamp.earned) c.accentInk else c.ink2, size = QsSize.iconM)
        }
        Text(stamp.name, style = QsType.caption2, color = if (stamp.earned) c.ink else c.ink2, textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** Grid of stamps (4 per row). */
@Composable
fun StampGrid(stamps: List<Stamp>, onTap: (Stamp) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
        stamps.chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                row.forEach { s -> StampBadge(s, Modifier.weight(1f).pressable(label = s.name) { onTap(s) }) }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** Reading stamps on Stats: the latest collected ones, plus the next one to collect with a gentle progress bar. */
@Composable
fun StampsCard(stamps: List<Stamp>, onOpen: () -> Unit) {
    val c = QsTheme.colors
    val firstRow = (stamps.filter { it.earned } + stamps.filter { !it.earned }).take(4)
    val next = Stamp.next(stamps)
    StatsCard(
        "Reading stamps",
        modifier = Modifier.pressable(label = "See all stamps", onClick = onOpen),
        trailing = { Text("${stamps.count { it.earned }} of ${stamps.size}", style = QsType.caption, color = c.ink2) },
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            firstRow.forEach { StampBadge(it, Modifier.weight(1f)) }
        }
        val p = next?.progress
        if (next != null && p != null) {
            Row(
                Modifier.fillMaxWidth().background(c.bg, RoundedCornerShape(QsTheme.shapes.inner)).padding(QsSpace.s12).semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
            ) {
                Box(Modifier.size(QsSpace.s32).background(c.soft2, CircleShape), contentAlignment = Alignment.Center) {
                    QsIcon(next.icon, tint = c.accentInk, size = QsSize.iconS)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                    Row {
                        Text("Next: ${next.name}", style = QsType.footnote.semibold(), color = c.ink, modifier = Modifier.weight(1f))
                        Text("${p.first.grouped()} of ${p.second.grouped()}", style = QsType.footnote, color = c.ink2)
                    }
                    QsProgressBar(p.first.toFloat() / p.second, small = true)
                    Text(next.how, style = QsType.caption, color = c.ink2)
                }
            }
        }
    }
}

/** "Cozy autumn · opt-in · ends 21 Dec – Read 3 books that felt cozy". */
@Composable
fun ChallengeCard(challenge: SeasonalChallenge, joined: Boolean, onTap: () -> Unit) {
    val c = QsTheme.colors
    val cover = QsSpace.s40
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(QsTheme.shapes.card)).background(c.soft)
            .pressable(label = if (joined) "Cozy autumn, joined" else "Join Cozy autumn", onClick = onTap)
            .semantics(mergeDescendants = true) {}.padding(QsSpace.s16),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
            QsIcon(R.drawable.ic_qs_flash, tint = c.ink2, size = QsSize.iconS)
            Text(if (joined) "Cozy autumn · joined" else "Cozy autumn · opt-in", style = QsType.caption.semibold(), color = c.ink2, modifier = Modifier.weight(1f))
            Text("ends ${challenge.end.dayOfMonth} ${challenge.end.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())}", style = QsType.caption, color = c.ink2)
        }
        Text("Read ${challenge.goal} books that felt cozy", style = QsTheme.headline(20), color = c.ink)
        Row(Modifier.clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            (0 until challenge.goal).forEach { i ->
                val b = challenge.books.getOrNull(i)
                if (b != null) BookCover(b.coverFile, b.title, width = cover) else {
                    Box(
                        Modifier.size(cover, cover * 1.5f).border(QsSize.stroke, c.lineStrong, RoundedCornerShape(QsTheme.shapes.cover)),
                        contentAlignment = Alignment.Center,
                    ) { Text("?", style = QsType.subheadline, color = c.ink2) }
                }
            }
        }
        Text("${minOf(challenge.books.size, challenge.goal)} of ${challenge.goal} · reward: “Autumn reads” stamp", style = QsType.footnote, color = c.ink2)
    }
}

/** Gentle legend line for the year-vs-year chart. */
@Composable
fun LegendLine(color: Color, dashed: Boolean, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s6)) {
        Canvas(Modifier.size(16.dp, 2.dp)) {
            drawLine(color, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), strokeWidth = 2.5.dp.toPx(),
                pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())) else null)
        }
        Text(text, style = QsType.caption, color = QsTheme.colors.ink2)
    }
}

/** Month tile for the Month view ("3 books finished"). */
@Composable
fun NumberTile(value: String, label: String, modifier: Modifier = Modifier) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    Column(
        modifier.clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape).padding(QsSpace.s16).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(QsSpace.s2),
    ) {
        Text(value, style = QsTheme.headline(28), color = c.ink)
        Text(label, style = QsType.footnote, color = c.ink2)
    }
}

fun percent(part: Int, total: Int): Int = if (total <= 0) 0 else (part.toDouble() / total * 100).roundToInt()

/** Labels like "4½" for half stars. */
fun starLabel(s: Double): String = if (s % 1.0 == 0.0) "${s.toInt()}" else "${s.toInt()}½"
