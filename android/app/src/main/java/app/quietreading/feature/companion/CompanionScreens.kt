package app.quietreading.feature.companion

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Book
import app.quietreading.data.BookEntity
import app.quietreading.data.BookSearch
import app.quietreading.data.BookSource
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.ChipFlow
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsButtonSize
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.QsProgressBar
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import app.quietreading.feature.add.rememberIsOnline
import app.quietreading.feature.book.QsSheet
import app.quietreading.feature.book.rememberAllBooks
import app.quietreading.feature.settings.QsSwitch
import app.quietreading.feature.stats.GoalCard
import app.quietreading.feature.stats.ReadingStats
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition

// Root: consent first, then the chat

@Composable
fun CompanionScreen(nav: AppNav) {
    val store = rememberCompanion()
    if (!store.loaded) { Box(Modifier.fillMaxSize().background(QsTheme.colors.bg)); return }
    if (store.isEnabled) CompanionChat(nav, store) else CompanionConsent(nav, store)
}

/**
 * Flow 12 › Consent: shown once before the first chat (Play policy, GDPR). Says plainly what Astrid sees,
 * what she never sees and where she runs. "Not now" keeps the whole app usable.
 */
@Composable
private fun CompanionConsent(nav: AppNav, store: CompanionStore) {
    val c = QsTheme.colors
    FlowScreen(
        title = null, onBack = nav::back, backLabel = "Close", closeInstead = true,
        actions = {
            QsButton("Turn on Astrid", { store.changeEnabled(true) })
            QsButton("Not now", nav::back, kind = QsButtonKind.Text)
        },
    ) {
        Box(Modifier.size(QsSpace.s64 + QsSpace.s8).background(c.aiSoft, CircleShape), contentAlignment = Alignment.Center) {
            QsIcon(R.drawable.ic_qs_sparkles, tint = c.aiInk, size = QsSpace.s32)
        }
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Text("Meet Astrid, your reading companion", style = QsTheme.headline(26), color = c.ink, modifier = Modifier.semantics { heading() })
            Text("Astrid is an AI. Chat about your books, get ideas for what to read next and see how your reading is going.", style = QsType.subheadline, color = c.ink2)
        }
        BulletBox("What it can see", listOf("Your shelves, ratings and finish tags", "Reading progress and goals"), c.surface)
        BulletBox("What it never sees", listOf("Your name, email, photo or location", "Your notes, unless you turn them on"), c.soft2)
        Text(
            "Runs on your phone with Gemini Nano, Google’s on-device model. Your questions and books don’t leave your phone. Book ideas are looked up in public catalogues by title only.",
            style = QsType.footnote, color = c.ink2,
        )
        SwitchRow("Include my notes", null, store.includeNotes, onChange = store::changeIncludeNotes)
    }
}

/** Row with a switch: the whole row toggles. */
@Composable
private fun SwitchRow(title: String, subtitle: String?, checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid)
            .then(if (enabled) Modifier.pressable(role = Role.Switch) { onChange(!checked) } else Modifier)
            .semantics(mergeDescendants = true) { selected = checked }
            .padding(vertical = QsSpace.s8),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(title, style = QsType.body, color = if (enabled) c.ink else c.disabledInk)
            if (subtitle != null) Text(subtitle, style = QsType.footnote, color = if (enabled) c.ink2 else c.disabledInk)
        }
        QsSwitch(checked, null)
    }
}

// Chat (Flow 12 › Steps 3–7)

@Composable
private fun CompanionChat(nav: AppNav, store: CompanionStore) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val app = LocalApp.current
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    val books = rememberAllBooks().orEmpty()
    val (goal, _) = rememberPref(Keys.goal, 0)
    val online = rememberIsOnline()
    val dictation = remember { Dictation(context) }
    DisposableEffect(Unit) { onDispose { dictation.release() } }
    var draft by rememberSaveable { mutableStateOf("") }
    var openPick by remember { mutableStateOf<Pair<CompanionPick, CompanionMessage>?>(null) }
    var menu by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    // Decided once when the chat opens: an earlier conversation exists → "Welcome back".
    val returning = remember { store.messages.isNotEmpty() }
    val list = rememberLazyListState()

    fun bookFor(title: String): Book? = books.firstOrNull { CompanionContext.key(it.title) == CompanionContext.key(title) }
    fun ask(text: String) = store.send(text, books, goal)
    fun followUp(f: String) {
        if (f == "Open my stats") { nav.back(); nav.openTab(Routes.STATS); return }
        ask(f)
    }

    /** "Add to Up next": saved to Want to read, with a message and Undo. */
    fun undo(pick: CompanionPick, m: CompanionMessage) {
        scope.launch {
            val key = Book.matchKey(pick.title, pick.author, null)
            app.library.books.first()
                .firstOrNull { Book.matchKey(it.title, it.author, null) == key && it.status == ReadingStatus.ToRead }
                ?.let { app.library.delete(it) }
            store.setPick(pick, m, CompanionPick.State.Open)
        }
    }
    fun add(pick: CompanionPick, m: CompanionMessage) {
        val key = Book.matchKey(pick.title, pick.author, pick.isbn)
        if (books.any { it.matchKey == key || CompanionContext.key(it.title) == CompanionContext.key(pick.title) }) {
            store.setPick(pick, m, CompanionPick.State.Added); return
        }
        scope.launch {
            val id = app.library.add(BookEntity(title = pick.title, author = pick.author, isbn = pick.isbn, pageCount = pick.pageCount,
                status = ReadingStatus.ToRead.raw, source = BookSource.Manual.raw))
            store.setPick(pick, m, CompanionPick.State.Added)
            notifier.show("Added to Up next", "Lovely choice. It’s waiting in Up next whenever you’re ready.", actionTitle = "Undo") { undo(pick, m) }
            BookSearch.coverBytes(pick.isbn, pick.coverUrl)?.let { bytes ->
                val name = app.covers.save(bytes) ?: return@let
                app.library.dao.book(id)?.let { app.library.dao.update(it.copy(coverFile = name)) }
            }
        }
    }

    LaunchedEffect(Unit) {
        store.refreshAvailability()
        store.pendingPrompt?.let { store.pendingPrompt = null; ask(it) }
    }
    val lastText = store.messages.lastOrNull()?.text?.length ?: 0
    LaunchedEffect(store.messages.size, store.phase, lastText) {
        val count = list.layoutInfo.totalItemsCount
        if (count > 0) list.animateScrollToItem(count - 1)
    }

    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        // Top bar
        Row(Modifier.fillMaxWidth().padding(horizontal = QsSpace.s4, vertical = QsSpace.s4), verticalAlignment = Alignment.CenterVertically) {
            QsIconButton(R.drawable.ic_qs_close, "Close", tint = c.ink, onClick = nav::back)
            Row(
                Modifier.weight(1f).semantics(mergeDescendants = true) { heading() },
                horizontalArrangement = Arrangement.spacedBy(QsSpace.s8, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                QsIcon(R.drawable.ic_qs_sparkles, tint = c.aiInk, size = 18.dp)
                Text("Astrid", style = QsType.body.semibold(), color = c.ink)
                AiPill()
            }
            Box {
                QsIconButton(R.drawable.ic_qs_more, "More", tint = c.ink) { menu = true }
                DropdownMenu(menu, { menu = false }, containerColor = c.surface) {
                    DropdownMenuItem({ Text("Astrid & privacy", color = c.ink) }, { menu = false; nav.controller.navigate(CompanionRoutes.SETTINGS) },
                        leadingIcon = { QsIcon(R.drawable.ic_qs_settings, tint = c.ink) })
                    DropdownMenuItem({ Text("Delete chat history", color = c.error) }, { menu = false; confirmDelete = true },
                        leadingIcon = { QsIcon(R.drawable.ic_qs_trash, tint = c.error) })
                }
            }
        }
        HorizontalDivider(thickness = QsSize.stroke, color = c.line)

        // Conversation
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(), state = list,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(QsSpace.s20),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            if (!online) item("offline") { InfoBanner("I can’t reach the library just now, so new book ideas will wait. I can still chat about your reading.") }
            item("ready") { ReadinessBanner(store) }
            item("intro") {
                val current = books.filter { it.status == ReadingStatus.Reading }.maxByOrNull { it.lastUpdated }
                val text = if (returning && current != null) "Welcome back. How is *${current.title}* treating you?"
                    else "Hello, I’m Astrid, your reading companion. I’m an AI, and I can only see your **shelves, ratings and finish tags**. I’d love to help you find your next good story. Where shall we start?"
                CompanionMessageRow(text, { bookFor(it) != null }) { t -> bookFor(t)?.let { nav.openBook(it.id) } }
            }
            if (store.messages.isEmpty()) item("starters") { Starters(books, ::ask) }
            items(store.messages, key = { it.id }) { m ->
                Box(Modifier.animateItem()) {
                    if (m.role == CompanionMessage.Role.Me) MyMessage(m) { store.retry(m, books, goal) }
                    else if (m.status == CompanionMessage.Status.Failed) InfoBanner(m.text, error = true)
                    else Answer(
                        m, store, books, goal,
                        isLatest = store.messages.lastOrNull { it.role == CompanionMessage.Role.Companion }?.id == m.id,
                        linkable = { bookFor(it) != null }, onTitle = { t -> bookFor(t)?.let { nav.openBook(it.id) } },
                        onOpen = { openPick = it to m }, onAdd = { add(it, m) }, onUndo = { undo(it, m) },
                        onFollowUp = ::followUp,
                        onCopy = {
                            (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Astrid", plain(m.text)))
                            notifier.show("Copied", "The answer is on your clipboard.")
                        },
                        onEditGoal = { nav.back(); nav.openTab(Routes.STATS) },
                    )
                }
            }
            if (store.phase == CompanionStore.Phase.Thinking) item("thinking") { ThinkingIndicator(onStop = store::stop) }
        }

        Composer(draft, { draft = it }, store, dictation) {
            dictation.stop()
            val text = draft
            draft = ""
            ask(text)
        }
    }

    openPick?.let { (pick, m) ->
        val live = store.messages.firstOrNull { it.id == m.id }?.picks?.firstOrNull { it.id == pick.id } ?: pick
        PickDetailSheet(live, onDismiss = { openPick = null }) { add(live, m); openPick = null }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete chat history?") },
            text = { Text("Your chats with Astrid are removed from this phone. Your books stay as they are.") },
            confirmButton = { TextButton({ confirmDelete = false; store.deleteHistory() }) { Text("Delete", color = c.error) } },
            dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel", color = c.accentInk) } },
            containerColor = c.surface,
        )
    }
}

/** Gemini Nano status: download offer with progress, or a calm "can't run here" line. */
@Composable
private fun ReadinessBanner(store: CompanionStore) {
    val c = QsTheme.colors
    when (store.availability) {
        Availability.Downloadable, Availability.Downloading -> {
            val shape = RoundedCornerShape(QsTheme.shapes.card)
            Column(Modifier.fillMaxWidth().background(c.aiSoft, shape).padding(QsSpace.s16), verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                Text("Astrid needs a one-time download", style = QsType.subheadline.semibold(), color = c.ink)
                Text("To talk about books, Gemini Nano is downloaded to your phone once. Your goal and reading numbers work already.", style = QsType.subheadline, color = c.ink)
                val d = store.download
                if (d != null) {
                    val (done, total) = d
                    QsProgressBar(if (total > 0) done.toFloat() / total else 0f)
                    Text(if (total > 0) "${done / 1_048_576} of ${total / 1_048_576} MB · keep the app open" else "Starting…", style = QsType.footnote, color = c.ink2)
                } else {
                    QsButton("Download", store::startDownload, kind = QsButtonKind.Secondary, size = QsButtonSize.Small)
                }
            }
        }
        Availability.Unavailable -> InfoBanner("Astrid can’t talk about books on this phone yet: it needs Gemini Nano. She can still tell you how your reading year is going.")
        else -> Unit
    }
}

@Composable
private fun Starters(books: List<Book>, ask: (String) -> Unit) {
    val c = QsTheme.colors
    val favourite = books.filter { it.status == ReadingStatus.Read }.maxByOrNull { it.stars ?: 0.0 }?.title ?: "Piranesi"
    val items = listOf("Find my next book", "Something like $favourite, but cosier", "How is my reading goal going?", "Plan reads for my holiday")
    Column(Modifier.padding(start = QsSpace.s40), verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        items.forEach { s ->
            val shape = RoundedCornerShape(QsTheme.shapes.field)
            Row(
                Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).clip(shape).background(c.surface).border(QsSize.stroke, c.line, shape)
                    .pressable { ask(s) }.padding(horizontal = QsSpace.s16, vertical = QsSpace.s12),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
            ) {
                Text(s, style = QsType.subheadline, color = c.ink, modifier = Modifier.weight(1f))
                QsIcon(R.drawable.ic_qs_send, tint = c.ink2, size = QsSize.iconS)
            }
        }
    }
}

@Composable
private fun MyMessage(m: CompanionMessage, onRetry: () -> Unit) {
    val c = QsTheme.colors
    Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) { contentDescription = "You: ${m.text}" }, horizontalAlignment = Alignment.End) {
        Text(
            m.text, style = QsType.subheadline, color = c.ink,
            modifier = Modifier.widthIn(max = 282.dp).background(c.soft2, RoundedCornerShape(QsTheme.shapes.card)).padding(horizontal = QsSpace.s16, vertical = QsSpace.s12),
        )
        if (m.status == CompanionMessage.Status.Failed) {
            Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(onClick = onRetry), contentAlignment = Alignment.Center) {
                Text("Not sent · Tap to try again", style = QsType.caption.medium(), color = c.error)
            }
        }
    }
}

@Composable
private fun Answer(
    m: CompanionMessage, store: CompanionStore, books: List<Book>, goal: Int, isLatest: Boolean,
    linkable: (String) -> Boolean, onTitle: (String) -> Unit,
    onOpen: (CompanionPick) -> Unit, onAdd: (CompanionPick) -> Unit, onUndo: (CompanionPick) -> Unit,
    onFollowUp: (String) -> Unit, onCopy: () -> Unit, onEditGoal: () -> Unit,
) {
    val reduce = QsTheme.reduceMotion
    var shown by remember { mutableStateOf(reduce) }
    LaunchedEffect(Unit) { shown = true }
    AnimatedVisibility(shown, enter = if (reduce) fadeIn(tween(QsMotion.fast)) else fadeIn(tween(QsMotion.slow)) + slideInVertically(tween(QsMotion.slow)) { it / 8 }) {
        Column(Modifier.animateContentSize(), verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            CompanionMessageRow(m.text, linkable, onTitle)
            if (m.status == CompanionMessage.Status.Done) {
                if (m.showGoal) {
                    val s = ReadingStats(books)
                    GoalCard(s.goal(goal, s.currentYear), s.currentYear, listOf(s.currentYear), onYear = {}, onEdit = onEditGoal)
                }
                m.picks.filter { it.state != CompanionPick.State.NotForMe }.forEach { pick ->
                    ChatBookCard(pick, onOpen = { onOpen(pick) }, onAdd = { onAdd(pick) }, onUndo = { onUndo(pick) },
                        onNotForMe = { store.setPick(pick, m, CompanionPick.State.NotForMe) })
                }
                if (isLatest && store.phase == CompanionStore.Phase.Idle) {
                    if (m.followUps.isNotEmpty()) {
                        Box(Modifier.padding(start = QsSpace.s40)) { ChipFlow { m.followUps.forEach { f -> QsChip(f) { onFollowUp(f) } } } }
                    }
                    Row(Modifier.padding(start = QsSpace.s32), horizontalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                        ActionIcon(R.drawable.ic_qs_thumbup, "Helpful", m.feedback == 1) { store.rate(m, 1) }
                        ActionIcon(R.drawable.ic_qs_thumbdown, "Not helpful", m.feedback == -1) { store.rate(m, -1) }
                        ActionIcon(R.drawable.ic_qs_copy, "Copy", false, onCopy)
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionIcon(icon: Int, label: String, active: Boolean, onClick: () -> Unit) {
    val c = QsTheme.colors
    Box(
        Modifier.size(QsSize.touchAndroid).clip(CircleShape).pressable(label = label, onClick = onClick)
            .semantics { contentDescription = label; selected = active },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(QsSpace.s32 + QsSpace.s4).background(if (active) c.soft2 else Color.Transparent, CircleShape), contentAlignment = Alignment.Center) {
            QsIcon(icon, tint = if (active) c.accentInk else c.ink2, size = 18.dp)
        }
    }
}

/** 🧱 Components › Chat book card: a real book inside an answer (max 3). Tap = why this pick. */
@Composable
private fun ChatBookCard(pick: CompanionPick, onOpen: () -> Unit, onAdd: () -> Unit, onUndo: () -> Unit, onNotForMe: () -> Unit) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.card)
    val meta = listOfNotNull(pick.author.takeIf { it.isNotEmpty() }, pick.pageCount?.let { "$it pages" }).joinToString(" · ")
    Row(
        Modifier.fillMaxWidth().background(c.surface, shape)
            .border(QsSize.stroke, if (pick.state == CompanionPick.State.Added) c.accent else c.line, shape).padding(QsSpace.s12),
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        BookCover(null, pick.title, Modifier.pressable(onClick = onOpen), width = 40.dp, url = pick.coverUrl)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
            Column(
                Modifier.fillMaxWidth().pressable(label = "Show why this pick", onClick = onOpen).semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(QsSpace.s4),
            ) {
                Text(pick.title, style = QsTheme.headline(17), color = c.ink)
                if (meta.isNotEmpty()) Text(meta, style = QsType.footnote, color = c.ink2)
                if (pick.reason.isNotEmpty()) Text(pick.reason, style = QsType.footnote, color = c.ink)
            }
            Row(Modifier.padding(top = QsSpace.s4), horizontalArrangement = Arrangement.spacedBy(QsSpace.s8), verticalAlignment = Alignment.CenterVertically) {
                if (pick.state == CompanionPick.State.Added) {
                    Box(Modifier.weight(1f)) { QsButton("In Up next", {}, kind = QsButtonKind.Secondary, size = QsButtonSize.Small, enabled = false) }
                    Box(Modifier.weight(1f)) { QsButton("Undo", onUndo, kind = QsButtonKind.Text, size = QsButtonSize.Small) }
                } else {
                    Box(Modifier.weight(1.3f)) { QsButton("Add to Up next", onAdd, kind = QsButtonKind.Secondary, size = QsButtonSize.Small) }
                    Box(Modifier.weight(1f)) { QsButton("Not for me", onNotForMe, kind = QsButtonKind.Text, size = QsButtonSize.Small) }
                }
            }
        }
    }
}

/** Tap a pick: the book with "Why this pick" and Add to Up next. */
@Composable
private fun PickDetailSheet(pick: CompanionPick, onDismiss: () -> Unit, onAdd: () -> Unit) {
    val c = QsTheme.colors
    QsSheet(onDismiss) {
        Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            BookCover(null, pick.title, width = 96.dp, url = pick.coverUrl)
            Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
                Text(pick.title, style = QsTheme.headline(24), color = c.ink, modifier = Modifier.semantics { heading() })
                Text(listOfNotNull(pick.author, pick.pageCount?.let { "$it pages" }).joinToString(" · "), style = QsType.subheadline, color = c.ink2)
                Row(
                    Modifier.background(c.aiSoft, CircleShape).padding(horizontal = QsSpace.s8, vertical = QsSpace.s4),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s4),
                ) {
                    QsIcon(R.drawable.ic_qs_sparkles, tint = c.aiInk, size = 12.dp)
                    Text("Suggested by Astrid · AI", style = QsType.caption.medium(), color = c.aiInk)
                }
            }
        }
        if (pick.reason.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().background(c.soft2, RoundedCornerShape(QsTheme.shapes.card)).padding(QsSpace.s16), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
                Text("WHY THIS PICK", style = QsType.caption2.semibold(), color = c.ink2)
                Text(pick.reason, style = QsType.subheadline, color = c.ink)
            }
        }
        Box(Modifier.padding(top = QsSpace.s8)) {
            if (pick.state == CompanionPick.State.Added) QsButton("In Up next", {}, kind = QsButtonKind.Secondary, enabled = false)
            else QsButton("Add to Up next", onAdd)
        }
    }
}

/** Composer: field with the mic 12 dp from its right edge, send button, and the AI footnote. */
@Composable
private fun Composer(draft: String, onDraft: (String) -> Unit, store: CompanionStore, dictation: Dictation, onSend: () -> Unit) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val reduce = QsTheme.reduceMotion
    var focused by remember { mutableStateOf(false) }
    val canSend = draft.isNotBlank() && store.phase == CompanionStore.Phase.Idle
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> if (ok) dictation.start() else dictation.denied() }
    LaunchedEffect(dictation.text) { if (dictation.text.isNotEmpty()) onDraft(dictation.text) }
    val pulse by rememberInfiniteTransition(label = "mic").animateFloat(
        1f, 1.06f, infiniteRepeatable(tween(QsMotion.slow), RepeatMode.Reverse), label = "pulse",
    )
    Column(
        Modifier.fillMaxWidth().background(c.bg).navigationBarsPadding().padding(horizontal = QsSpace.s16, vertical = QsSpace.s8),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            val shape = RoundedCornerShape(22.dp)
            Box(
                Modifier.weight(1f).heightIn(min = 44.dp).background(c.surface, shape)
                    .border(if (focused) QsSize.focusRing else QsSize.stroke, if (focused) c.focus else c.lineStrong, shape),
            ) {
                BasicTextField(
                    draft, onDraft,
                    modifier = Modifier.fillMaxWidth().padding(start = QsSpace.s16, end = 44.dp, top = QsSpace.s12, bottom = QsSpace.s12)
                        .onFocusChanged { focused = it.isFocused }
                        .semantics { contentDescription = "Ask about your reading" },
                    textStyle = QsType.subheadline.copy(color = c.ink),
                    cursorBrush = SolidColor(c.accent),
                    maxLines = 4,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                    decorationBox = { inner ->
                        if (draft.isEmpty()) Text("Ask about your reading…", style = QsType.subheadline, color = c.ink2)
                        inner()
                    },
                )
                // Mic: 20 dp icon centred in a 44 dp area, so it sits 12 dp from the field's right edge.
                Box(
                    Modifier.align(Alignment.BottomEnd).size(44.dp).minimumInteractiveComponentSize().clip(CircleShape)
                        .pressable(label = if (dictation.isListening) "Stop dictation" else "Dictate") {
                            when {
                                dictation.isListening -> dictation.stop()
                                ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED -> dictation.start()
                                else -> permission.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(QsSpace.s32 + QsSpace.s4).scale(if (dictation.isListening && !reduce) pulse else 1f)
                            .background(if (dictation.isListening) c.accent else Color.Transparent, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) { QsIcon(R.drawable.ic_qs_mic, tint = if (dictation.isListening) c.onAccent else c.ink2, size = QsSize.iconM) }
                }
            }
            Box(
                Modifier.size(QsSize.touchAndroid).clip(CircleShape).background(if (canSend) c.accent else c.disabledBg)
                    .pressable(enabled = canSend, label = "Send", onClick = onSend).semantics { contentDescription = "Send" },
                contentAlignment = Alignment.Center,
            ) { QsIcon(R.drawable.ic_qs_send, tint = if (canSend) c.onAccent else c.disabledInk, size = QsSize.iconM) }
        }
        when (dictation.state) {
            Dictation.State.Denied -> Text("To speak to Astrid, allow the microphone in Settings › Apps › Quiet Reading.", style = QsType.caption2, color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Dictation.State.Unavailable -> Text("Speaking isn’t available on this phone. Typing works as usual.", style = QsType.caption2, color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            else -> Unit
        }
        Text("AI · can be wrong · stays on your phone", style = QsType.caption2.medium(), color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
}

// Settings · Astrid & privacy

/** Flow 12 › Settings · Astrid & privacy. Everything in one place; mirrors the consent screen. */
@Composable
fun CompanionSettingsScreen(nav: AppNav) {
    val c = QsTheme.colors
    val store = rememberCompanion()
    var confirmDelete by remember { mutableStateOf(false) }
    var showSees by remember { mutableStateOf(false) }
    var historyMenu by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { store.refreshAvailability() }
    FlowScreen("Astrid & privacy", onBack = nav::back) {
        val shape = RoundedCornerShape(QsTheme.shapes.card)
        Column(Modifier.fillMaxWidth().background(c.surface, shape).border(QsSize.stroke, c.line, shape).padding(horizontal = QsSpace.s16, vertical = QsSpace.s4)) {
            SwitchRow("Astrid, reading companion", "AI chat, book ideas and reading insights", store.isEnabled) { store.changeEnabled(it) }
            HorizontalDivider(thickness = QsSize.stroke, color = c.line)
            SwitchRow("On-device only", "Private and offline with Gemini Nano. Cloud answers for other phones come later.", true, enabled = false) {}
            HorizontalDivider(thickness = QsSize.stroke, color = c.line)
            SwitchRow("Include my notes", "Lets Astrid talk about what you wrote", store.includeNotes, enabled = store.isEnabled, onChange = store::changeIncludeNotes)
        }
        QsListCard(rows = listOf(
            { QsListRow(R.drawable.ic_qs_info, "What Astrid sees") { showSees = true } },
            {
                Box {
                    QsListRow(R.drawable.ic_qs_calendar, "Chat history", subtitle = when (store.historyDays) { 0 -> "Not kept"; 7 -> "Keep for 7 days"; else -> "Keep for 30 days" }) { historyMenu = true }
                    DropdownMenu(historyMenu, { historyMenu = false }, containerColor = c.surface) {
                        listOf(30 to "Keep for 30 days", 7 to "Keep for 7 days", 0 to "Don’t keep").forEach { (d, label) ->
                            DropdownMenuItem({ Text(label, color = c.ink) }, { historyMenu = false; store.changeHistoryDays(d) },
                                trailingIcon = { if (store.historyDays == d) QsIcon(R.drawable.ic_qs_check, tint = c.accentInk) })
                        }
                    }
                }
            },
            {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).pressable { confirmDelete = true }.padding(QsSpace.s16),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
                ) {
                    Box(Modifier.size(QsSpace.s40).background(c.errorSoft, RoundedCornerShape(QsTheme.shapes.field)), contentAlignment = Alignment.Center) {
                        QsIcon(R.drawable.ic_qs_trash, tint = c.error, size = 22.dp)
                    }
                    Text("Delete chat history", style = QsType.body.medium(), color = c.error)
                }
            },
        ))
        Text(
            when (store.availability) {
                Availability.Available -> "Gemini Nano is ready on this phone. Chats stay on your phone."
                Availability.Downloadable, Availability.Downloading -> "Gemini Nano needs a one-time download on this phone. Goal and reading numbers work without it."
                Availability.Checking -> "Checking this phone…"
                Availability.Unavailable -> "This phone can’t run Gemini Nano. Astrid can still answer questions about your goal and reading numbers."
            },
            style = QsType.footnote, color = c.ink2,
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete chat history?") },
            text = { Text("Your chats with Astrid are removed from this phone. Your books stay as they are.") },
            confirmButton = { TextButton({ confirmDelete = false; store.deleteHistory() }) { Text("Delete", color = c.error) } },
            dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel", color = c.accentInk) } },
            containerColor = c.surface,
        )
    }
    if (showSees) {
        QsSheet({ showSees = false }) {
            Text("What Astrid sees", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
            Text("It can see", style = QsType.subheadline.semibold(), color = c.ink)
            (listOf("Titles, authors, ratings and moods of your books", "Your shelves, reading progress and goal") +
                (if (store.includeNotes) listOf("Your reading notes (you turned this on)") else emptyList()))
                .forEach { Text("•  $it", style = QsType.subheadline, color = c.ink) }
            Text("It never sees", style = QsType.subheadline.semibold(), color = c.ink)
            (listOf("Your name, email, photo or location") + (if (store.includeNotes) emptyList() else listOf("Your notes")))
                .forEach { Text("•  $it", style = QsType.subheadline, color = c.ink) }
            Text("Everything runs on your phone. To find book ideas, only a short search like “cosy fantasy” goes to Google Books and Open Library.", style = QsType.footnote, color = c.ink2)
        }
    }
}
