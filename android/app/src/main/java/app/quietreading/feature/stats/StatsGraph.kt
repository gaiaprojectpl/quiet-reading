package app.quietreading.feature.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Book
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.current
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsButtonSize
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.QsSegmented
import app.quietreading.designsystem.components.ScreenHeader
import app.quietreading.designsystem.components.TabScreen
import app.quietreading.designsystem.medium
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

/** Stats routes: the tab plus Reading stamps, Year in books and Patterns. */
object StatsRoutes {
    const val STAMPS = "stats/stamps"
    const val PATTERNS = "stats/patterns"
    const val YEAR = "stats/year/{year}"
    fun year(year: Int = LocalDate.now().year) = "stats/year/$year"
}

/** Stats preferences (same names as iOS). */
object StatsKeys {
    val weeklyDays = intPreferencesKey("weeklyDaysGoal")
    val stampsSeen = stringPreferencesKey("stampsSeen")
    val joined = booleanPreferencesKey(SeasonalChallenge.JOINED_KEY)
}

fun NavGraphBuilder.statsGraph(nav: AppNav) {
    composable(Routes.STATS) { StatsScreen(nav) }
    composable(StatsRoutes.STAMPS) { StampsScreen(nav) }
    composable(StatsRoutes.PATTERNS) { PatternsScreen(nav) }
    composable(StatsRoutes.YEAR, arguments = listOf(navArgument("year") { type = NavType.IntType })) { entry ->
        YearInBooksScreen(nav, entry.arguments?.getInt("year") ?: LocalDate.now().year)
    }
}

/** The books, as live state, for every Stats screen. */
@Composable
fun rememberBooks(): List<Book> {
    val library = LocalApp.current.library
    return library.books.collectAsState(initial = emptyList()).value
}

private enum class Period(val title: String) { Week("Week"), Month("Month"), Year("Year") }

/**
 * Flow 8 / 8b · Stats. Gentle and free: goal ring, weekly rhythm, pages, reading days, books per month,
 * the shelf of spines and stamps. Patterns (moods, pace…) are Plus. Goals are optional and never shame.
 */
@Composable
fun StatsScreen(nav: AppNav) {
    val app = LocalApp.current
    val context = LocalContext.current
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    val books = rememberBooks()
    val stats = remember(books) { ReadingStats(books) }
    val (goal, setGoal) = rememberPref(Keys.goal, 0)
    val (weeklyDays, setWeeklyDays) = rememberPref(StatsKeys.weeklyDays, 4)
    val (stampsSeen, setStampsSeen) = rememberPref(StatsKeys.stampsSeen, "")
    val (joined, setJoined) = rememberPref(StatsKeys.joined, false)
    val (name, _) = rememberPref(Keys.name, "")
    val plus by app.prefs.flow(Keys.plusUnlocked, false).collectAsState(initial = false)

    var period by rememberSaveable { mutableStateOf(Period.Year) }
    var year by rememberSaveable { mutableStateOf(LocalDate.now().year) }
    var monthText by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    val month = YearMonth.parse(monthText)
    var editingGoal by remember { mutableStateOf(false) }
    var showJoin by remember { mutableStateOf(false) }

    val challenge = remember(stats) { SeasonalChallenge.of(stats) }
    val stamps = remember(stats, joined) { Stamp.all(stats, autumnDone = joined && (challenge?.done ?: false)) }
    val current = books.current

    // A newly earned stamp gets one quiet notification (the first visit only remembers what's already there).
    LaunchedEffect(stamps.filter { it.earned }.map { it.id }, stampsSeen) {
        if (books.isEmpty()) return@LaunchedEffect
        val earned = stamps.filter { it.earned }
        val ids = if (earned.isEmpty()) "-" else earned.joinToString(",") { it.id }
        if (ids == stampsSeen) return@LaunchedEffect
        val seen = stampsSeen.split(",").toSet()
        val firstVisit = stampsSeen.isEmpty()
        setStampsSeen(ids)
        val new = earned.firstOrNull { it.id !in seen }
        if (!firstVisit && new != null) {
            notifier.show("New stamp: ${new.name}", "It’s in your stamps, kept for good.", actionTitle = "See") {
                nav.controller.navigate(StatsRoutes.STAMPS)
            }
        }
    }

    val who = name.ifBlank { "I" }
    val shareTitle = when (period) {
        Period.Week -> "$who read ${stats.thisWeek.sumOf { it.pages }} pages this week"
        Period.Month -> "$who finished ${stats.booksFinished(month).size} books in ${month.monthName()}"
        Period.Year -> "$who read ${stats.finished(year).size} books in $year"
    }
    val theme = QsTheme.id
    val share: () -> Unit = {
        scope.launch {
            val (shareBooks, detail) = when (period) {
                Period.Week -> listOfNotNull(current) to "Read on ${stats.thisWeek.count { it.didRead }} of 7 days"
                Period.Month -> {
                    val f = stats.booksFinished(month)
                    val days = stats.days(month)
                    (if (f.isEmpty()) listOfNotNull(current) else f.takeLast(3)) to "${days.sumOf { it.pages }.grouped()} pages · ${days.count { it.didRead }} reading days"
                }
                Period.Year -> stats.finished(year).takeLast(3) to "${stats.pages(year).grouped()} pages · ${stats.newAuthors(year)} new authors"
            }
            val file = StatsShareCard.file(context, app.covers, shareBooks, shareTitle, detail, theme)
            if (file != null) StatsShareCard.share(context, file, shareTitle)
            else notifier.show("The image isn’t ready", "Try sharing again in a moment.", kind = NoticeKind.Error)
        }
    }

    TabScreen("Stats", header = {
        ScreenHeader("Stats") {
            if (stats.hasAnyData) QsIconButton(R.drawable.ic_qs_share, "Share", onClick = share)
        }
    }) {
        if (!stats.hasAnyData) {
            // iPhone/phone tab screens keep empty-state buttons inline (Kaja's exception).
            Column(Modifier.fillMaxWidth().padding(top = QsSpace.s48), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
                EmptyState(R.drawable.ic_qs_stats, "Your stats will grow with you", "Update a page or finish a book and this space fills in. Nothing to catch up on.")
                if (current != null) {
                    QsButton("Update my book", { nav.openBook(current.id) }, Modifier.widthIn(max = 220.dp), size = QsButtonSize.Small)
                } else {
                    QsButton("Add a book", nav.showAddSheet, Modifier.widthIn(max = 220.dp), size = QsButtonSize.Small)
                }
            }
            return@TabScreen
        }
        QsSegmented(Period.entries.map { it to it.title }, period) { period = it }

        val gamification: @Composable ColumnScope.() -> Unit = {
            StampsCard(stamps) { nav.controller.navigate(StatsRoutes.STAMPS) }
            if (challenge != null) ChallengeCard(challenge, joined) { showJoin = true }
        }
        // Kaja, 27 Nov: collecting is the engaging part, so stamps and the seasonal challenge
        // sit right under the first card in every view.
        when (period) {
            Period.Week -> {
                RhythmCard(stats.thisWeek, weeklyDays) { setWeeklyDays(it) }
                gamification()
                PagesWeekCard(stats.thisWeek)
            }
            Period.Month -> {
                Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                    NumberTile("${stats.booksFinished(month).size}", "books finished", Modifier.weight(1f))
                    NumberTile(stats.days(month).sumOf { it.pages }.grouped(), "pages read", Modifier.weight(1f))
                }
                gamification()
                ReadingDaysCard(stats, month) { monthText = it.toString() }
            }
            Period.Year -> {
                GoalCard(stats.goal(goal, year), year, stats.years, { year = it }) { editingGoal = true }
                gamification()
                RhythmCard(stats.thisWeek, weeklyDays) { setWeeklyDays(it) }
                PagesWeekCard(stats.thisWeek)
                ReadingDaysCard(stats, month) { monthText = it.toString() }
                BooksPerMonthCard(stats.booksPerMonth(year), year, stats.years) { year = it }
                ShelfCard(stats.finished(year), year) { nav.openBook(it.id) }
            }
        }
        QsListCard(rows = listOf(
            { QsListRow(R.drawable.ic_qs_calendar, "Your $year in books", "Covers, numbers and a card to share") { nav.controller.navigate(StatsRoutes.year(year)) } },
            { QsListRow(R.drawable.ic_qs_crown, "Patterns", if (plus) "Moods, pace, when you read" else "Moods, pace, when you read · Plus") { nav.controller.navigate(StatsRoutes.PATTERNS) } },
        ))
    }

    if (editingGoal) GoalSheet(goal, stats.finished(stats.currentYear).size, onDismiss = { editingGoal = false }) { new ->
        val changed = new != goal
        setGoal(new)
        editingGoal = false
        if (changed) {
            if (new == 0) notifier.show("Goal turned off", "Your stats keep counting quietly.")
            else {
                val left = maxOf(0, new - stats.finished(stats.currentYear).size)
                notifier.show("New goal: $new books", if (left == 0) "You've already reached it." else "$left to go this year. No rush.")
            }
        }
    }
    if (showJoin && challenge != null) JoinChallengeSheet(challenge, joined, onDismiss = { showJoin = false }) { setJoined(it); showJoin = false }
}

/** Bottom sheet shell: surface, sheet radius, 20 dp sides, actions 24 dp above the bottom line. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QsSheet(onDismiss: () -> Unit, title: String? = null, content: @Composable ColumnScope.() -> Unit) {
    val c = QsTheme.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.surface,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            if (title != null) Text(title, style = QsTheme.headline(24), color = c.ink, modifier = Modifier.semantics { heading() })
            content()
        }
    }
}

/** A typed number field (never a stepper): 40 dp, lineStrong border, focus ring. */
@Composable
fun NumberField(value: String, onValue: (String) -> Unit, label: String, suffix: String? = null, error: Boolean = false, focus: FocusRequester? = null, onDone: (() -> Unit)? = null) {
    val c = QsTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val shape = RoundedCornerShape(QsTheme.shapes.field)
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).background(c.surface, shape)
            .border(if (focused) QsSize.focusRing else QsSize.stroke, when { error -> c.error; focused -> c.focus; else -> c.lineStrong }, shape)
            .padding(horizontal = QsSpace.s16),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicTextField(
            value, { v -> onValue(v.filter { it.isDigit() }.take(5)) },
            modifier = Modifier.weight(1f).then(if (focus != null) Modifier.focusRequester(focus) else Modifier).semantics { contentDescription = label },
            textStyle = QsType.body.copy(color = c.ink),
            singleLine = true,
            cursorBrush = SolidColor(c.accent),
            interactionSource = interaction,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { onDone?.invoke() }),
            decorationBox = { inner ->
                Box { if (value.isEmpty()) Text(label, style = QsType.body, color = c.ink2); inner() }
            },
        )
        if (suffix != null) Text(suffix, style = QsType.body, color = c.ink2)
    }
}

/** Flow 8 › Edit goal. Typed number. Goals are optional: empty or 0 turns it off. */
@Composable
fun GoalSheet(goal: Int, finishedThisYear: Int, onDismiss: () -> Unit, onSave: (Int) -> Unit) {
    val c = QsTheme.colors
    val year = LocalDate.now().year
    var text by remember { mutableStateOf(if (goal > 0) goal.toString() else "") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    QsSheet(onDismiss, "Reading goal") {
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Text("Books in $year", style = QsType.footnote.medium(), color = c.ink2)
            NumberField(text, { text = it }, "Books in $year", suffix = "books", focus = focus, onDone = { onSave(text.toIntOrNull() ?: 0) })
            Text("Type any number. Leave it empty to turn the goal off.", style = QsType.footnote, color = c.ink2)
        }
        InfoBanner("Goals are optional. No streaks, no guilt.")
        QsButton("Save", { onSave(maxOf(0, text.toIntOrNull() ?: 0)) })
    }
}

/** Opt-in sheet for the seasonal challenge. Leaving is one tap, nothing is lost. */
@Composable
fun JoinChallengeSheet(challenge: SeasonalChallenge, joined: Boolean, onDismiss: () -> Unit, onJoined: (Boolean) -> Unit) {
    val c = QsTheme.colors
    QsSheet(onDismiss, "Cozy autumn") {
        Text("Opt-in · ends ${challenge.end.dayOfMonth} ${challenge.end.month.getDisplayName(TextStyle.FULL, Locale.getDefault())}", style = QsType.footnote, color = c.ink2)
        Text("Read ${challenge.goal} books that felt cozy. Books you already finished this autumn count. Leaving is one tap, nothing is lost.", style = QsType.body, color = c.ink)
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            if (joined) {
                QsButton("Leave", { onJoined(false) }, Modifier.weight(1f), kind = QsButtonKind.Outline)
                QsButton("Keep going", onDismiss, Modifier.weight(1f))
            } else {
                QsButton("Join", { onJoined(true) }, Modifier.weight(1f))
                QsButton("Not now", onDismiss, Modifier.weight(1f), kind = QsButtonKind.Outline)
            }
        }
    }
}

/** Stamp detail: collected or how to get it, with progress. */
@Composable
fun StampDetailSheet(stamp: Stamp, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    QsSheet(onDismiss) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            StampBadge(stamp, size = QsSpace.s64)
            Text(if (stamp.earned) "Collected" else "Not yet", style = QsTheme.headline(20), color = c.ink)
            Text(stamp.how, style = QsType.body, color = c.ink2, textAlign = TextAlign.Center)
            val p = stamp.progress
            if (!stamp.earned && p != null) {
                Column(Modifier.widthIn(max = 220.dp).semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                    QsProgressBar(p.first.toFloat() / p.second, small = true)
                    Text("${p.first.grouped()} of ${p.second.grouped()}", style = QsType.footnote, color = c.ink2)
                }
            }
        }
    }
}
