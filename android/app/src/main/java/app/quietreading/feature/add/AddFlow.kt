package app.quietreading.feature.add

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.data.AppEnvironment
import app.quietreading.data.Book
import app.quietreading.data.BookCandidate
import app.quietreading.data.BookEntity
import app.quietreading.data.BookSearch
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.EmptyState
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.NoticeKind
import app.quietreading.designsystem.components.Notifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.Secondary
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import app.quietreading.designsystem.semibold
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private class Confirmation(val candidates: List<BookCandidate>, val photo: Bitmap?)
private class NoMatch(val photo: Bitmap?, val title: String, val author: String, val heading: String = "We couldn’t find this book", val showsWarning: Boolean = true)

private enum class CamStatus { Idle, Reading, Searching, TooDark, NotAvailable }

/** Flow 2 · Add a book: Photograph the cover / Scan the barcode / Type → Is this the book? → Added. */
@Composable
fun AddFlowScreen(initial: AddMode, nav: AppNav) {
    var mode by rememberSaveable { mutableStateOf(initial) }
    var confirm by remember { mutableStateOf<Confirmation?>(null) }
    var noMatch by remember { mutableStateOf<NoMatch?>(null) }
    val done = { nav.back() }

    val nm = noMatch
    if (nm != null) {
        BackHandler { noMatch = null }
        NoMatchScreen(nm, onBack = { noMatch = null }, onDone = done)
    } else if (mode == AddMode.Type) {
        TypeSearch(
            onMode = { mode = it },
            onPick = { picked, results -> confirm = Confirmation(listOf(picked) + results.filter { it.id != picked.id }.take(2), null) },
            onByHand = { q -> noMatch = NoMatch(null, q, "", heading = "Add by hand", showsWarning = false) },
            onCancel = done,
        )
    } else {
        CameraScreen(
            mode = mode,
            onMode = { mode = it },
            onFound = { results, photo -> confirm = Confirmation(results.take(3), photo) },
            onNoMatch = { photo, title, author -> noMatch = NoMatch(photo, title, author) },
            onCancel = done,
        )
    }
    confirm?.let { c -> ConfirmEditionSheet(c.candidates, c.photo, onDismiss = { confirm = null }, onAdded = { confirm = null; done() }) }
}

// MARK: Camera (Flow 2 › Step 3)

@Composable
private fun CameraScreen(
    mode: AddMode,
    onMode: (AddMode) -> Unit,
    onFound: (List<BookCandidate>, Bitmap?) -> Unit,
    onNoMatch: (Bitmap?, String, String) -> Unit,
    onCancel: () -> Unit,
) {
    val context = LocalContext.current
    val c = QsTheme.colors
    val scope = rememberCoroutineScope()
    val controller = remember { CameraController() }
    val hasCamera = remember { context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) }
    var status by remember { mutableStateOf(if (hasCamera) CamStatus.Idle else CamStatus.NotAvailable) }
    var allowed by remember { mutableStateOf(granted(context)) }
    var denied by remember { mutableStateOf(false) }
    var asked by rememberSaveable { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        allowed = ok
        if (!ok) denied = true
    }
    LaunchedEffect(Unit) {
        if (hasCamera && !allowed && !asked) { asked = true; launcher.launch(Manifest.permission.CAMERA) }
    }
    // Back from system Settings: the camera may be allowed now.
    LifecycleResumeEffect(Unit) {
        allowed = granted(context)
        if (allowed) denied = false
        onPauseOrDispose {}
    }

    fun lookup(isbn: String) {
        if (status == CamStatus.Searching) return
        scope.launch {
            status = CamStatus.Searching
            val results = BookSearch.lookup(isbn)
            status = CamStatus.Idle
            if (results.isEmpty()) onNoMatch(null, "", "") else onFound(results, null)
        }
    }

    fun shoot() {
        scope.launch {
            status = CamStatus.Reading
            val photo = controller.capturePhoto(context) ?: run { status = CamStatus.Idle; return@launch }
            val read = CoverReader.read(photo)
            if (read.isTooDark) { status = CamStatus.TooDark; return@launch }
            status = CamStatus.Searching
            val cover = CoverCropper.crop(photo)
            val results = BookSearch.search(read.query)
            status = CamStatus.Idle
            if (results.isEmpty()) onNoMatch(cover, read.lines.firstOrNull().orEmpty(), read.lines.getOrNull(1).orEmpty())
            else onFound(results, cover)
        }
    }

    Column(
        Modifier.fillMaxSize().background(QsSystemColor.camera).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable(label = "Cancel", onClick = onCancel), contentAlignment = Alignment.Center) {
                Text("Cancel", style = QsType.body.medium(), color = QsSystemColor.onCamera)
            }
            Spacer(Modifier.weight(1f))
            QsIconButton(
                R.drawable.ic_qs_flash, if (controller.torchOn) "Turn off the flash" else "Turn on the flash",
                tint = if (controller.torchOn) Color(0xFFFFD60A) else QsSystemColor.onCamera,
            ) { controller.toggleTorch() }
        }
        // Viewfinder
        val vfShape = RoundedCornerShape(QsTheme.shapes.sheet)
        Box(
            Modifier.fillMaxWidth().weight(1f, fill = false).heightIn(max = 470.dp).size(width = 10000.dp, height = 470.dp)
                .clip(vfShape).background(QsSystemColor.viewfinder)
                .semantics {
                    contentDescription = if (mode == AddMode.Barcode) "Camera. Point at the barcode on the back of the book." else "Camera. Fill the frame with the cover."
                },
            contentAlignment = Alignment.Center,
        ) {
            if (allowed && hasCamera) {
                CameraView(barcode = mode == AddMode.Barcode, controller = controller, onISBN = ::lookup, modifier = Modifier.fillMaxSize())
            } else if (status == CamStatus.NotAvailable) {
                Text("The camera isn’t available here. Type the title instead.", style = QsType.subheadline,
                    color = QsSystemColor.onCamera.copy(alpha = 0.8f), textAlign = TextAlign.Center, modifier = Modifier.padding(QsSpace.s24))
            }
            ViewfinderCorners(Modifier.fillMaxSize().padding(QsSpace.s24))
            if (status == CamStatus.TooDark) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)))
        }
        StatusPill(status, mode)
        Spacer(Modifier.weight(0.01f))
        ModePicker(mode, dark = true, onMode = onMode)
        if (mode == AddMode.Cover) {
            val enabled = status != CamStatus.Reading && status != CamStatus.Searching && allowed
            Box(
                Modifier.size(72.dp).clip(CircleShape).border(4.dp, QsSystemColor.onCamera.copy(alpha = if (enabled) 1f else 0.4f), CircleShape)
                    .pressable(enabled = enabled, label = "Take photo") { shoot() }
                    .semantics { contentDescription = "Take photo" },
                contentAlignment = Alignment.Center,
            ) { Box(Modifier.size(56.dp).background(QsSystemColor.onCamera.copy(alpha = if (enabled) 1f else 0.4f), CircleShape)) }
        }
    }

    if (denied) {
        AlertDialog(
            onDismissRequest = { denied = false },
            title = { Text("Allow camera access?") },
            text = { Text("Quiet Reading uses the camera only to read covers and barcodes. Photos stay on your phone.") },
            confirmButton = { TextButton({ denied = false; context.openAppSettings() }) { Text("Open settings", color = c.accentInk) } },
            dismissButton = { TextButton({ denied = false; onMode(AddMode.Type) }) { Text("Type it instead", color = c.accentInk) } },
            containerColor = c.surface, titleContentColor = c.ink, textContentColor = c.ink2,
        )
    }
}

private fun granted(context: android.content.Context) =
    androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

@Composable
private fun StatusPill(status: CamStatus, mode: AddMode) {
    val c = QsTheme.colors
    val (text, isError) = when (status) {
        CamStatus.TooDark -> "Too dark. Turn on the light or the flash." to true
        CamStatus.Reading -> "Hold still… reading the title" to false
        CamStatus.Searching -> "Looking for the book…" to false
        CamStatus.NotAvailable -> "Type works without the camera" to false
        CamStatus.Idle -> (if (mode == AddMode.Barcode) "Point at the barcode on the back" else "Fill the frame with the cover") to false
    }
    val bg by animateColorAsState(if (isError) c.error else Color.Black.copy(alpha = 0.6f), tween(QsMotion.base), label = "pill")
    Row(
        Modifier.background(bg, CircleShape).padding(horizontal = QsSpace.s16, vertical = QsSpace.s8).semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
    ) {
        if (isError) QsIcon(R.drawable.ic_qs_alert, tint = QsSystemColor.onCamera, size = QsSize.iconS + 2.dp)
        Text(text, style = QsType.subheadline.medium(), color = QsSystemColor.onCamera)
    }
}

/** The four corner marks of the viewfinder. */
@Composable
private fun ViewfinderCorners(modifier: Modifier) {
    Canvas(modifier) {
        val w = size.width; val h = size.height; val l = 16.dp.toPx()
        val p = Path().apply {
            moveTo(0f, l); lineTo(0f, 0f); lineTo(l, 0f)
            moveTo(w - l, 0f); lineTo(w, 0f); lineTo(w, l)
            moveTo(w, h - l); lineTo(w, h); lineTo(w - l, h)
            moveTo(l, h); lineTo(0f, h); lineTo(0f, h - l)
        }
        drawPath(p, QsSystemColor.onCamera, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** Cover / Barcode / Type switch (dark on the camera, light on Type). */
@Composable
private fun ModePicker(mode: AddMode, dark: Boolean, onMode: (AddMode) -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.background(if (dark) Color.White.copy(alpha = 0.14f) else c.soft2, CircleShape).padding(QsSpace.s4),
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        listOf(AddMode.Cover to "Cover", AddMode.Barcode to "Barcode", AddMode.Type to "Type").forEach { (m, title) ->
            val selected = m == mode
            val bg by animateColorAsState(
                if (selected) (if (dark) Color.White else c.surface) else Color.Transparent,
                tween(if (QsTheme.reduceMotion) 0 else QsMotion.fast), label = "mode",
            )
            Box(
                Modifier.heightIn(min = QsSize.touchAndroid - QsSpace.s8).clip(CircleShape).background(bg)
                    .pressable { onMode(m) }
                    .semantics { role = Role.Tab; this.selected = selected }
                    .padding(horizontal = QsSpace.s16, vertical = QsSpace.s8),
                contentAlignment = Alignment.Center,
            ) {
                Text(title, style = QsType.subheadline.medium(),
                    color = if (selected) (if (dark) QsSystemColor.camera else c.ink) else (if (dark) QsSystemColor.onCamera else c.ink))
            }
        }
    }
}

// MARK: Type (search by title or author)

@Composable
private fun TypeSearch(onMode: (AddMode) -> Unit, onPick: (BookCandidate, List<BookCandidate>) -> Unit, onByHand: (String) -> Unit, onCancel: () -> Unit) {
    val c = QsTheme.colors
    val online = rememberIsOnline()
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    var query by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<List<BookCandidate>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var searched by remember { mutableStateOf(false) }
    var slow by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    // Offline, keep the keyboard closed so the calm message is readable.
    LaunchedEffect(Unit) { if (online) runCatching { focus.requestFocus() } }

    fun search() {
        if (!online || query.isBlank()) return
        scope.launch {
            searching = true; slow = false
            // Flow 10 › B3 · over 8 s: say why and offer a way out (the typed text is kept).
            val watchdog = launch {
                delay(8_000)
                if (searching) {
                    slow = true
                    notifier.show("Still searching", "Slow connections can take a little longer.", NoticeKind.Info)
                }
            }
            results = BookSearch.search(query)
            watchdog.cancel()
            searching = false; searched = true
        }
    }

    FlowScreen(
        title = null,
        onBack = onCancel,
        backLabel = "Cancel",
        closeInstead = true,
        actions = {
            if (!online) {
                QsButton("Add by hand", { onByHand(query) })
                QsButton("Scan the barcode instead", { onMode(AddMode.Barcode) }, kind = QsButtonKind.Text)
            } else if (slow) {
                QsButton("Add by hand", { onByHand(query) }, kind = QsButtonKind.Secondary)
            }
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { ModePicker(AddMode.Type, dark = false, onMode = onMode) }
        },
    ) {
        Text("Search by title or author", style = QsTheme.headline(28), color = c.ink, modifier = Modifier.semantics { heading() })
        QsTextField(
            query, { query = it }, "Title or author", Modifier.focusRequester(focus),
            leadingIcon = R.drawable.ic_qs_search, imeAction = ImeAction.Search, capitalization = KeyboardCapitalization.None, onSubmit = ::search,
        )
        when {
            !online -> EmptyState(R.drawable.ic_qs_cloudoff, "Search needs a connection",
                "You can still add the book by hand. Its cover and details will fill in when you’re back online.")
            searching -> {
                Secondary("Searching Open Library and Google Books…")
                Column(Modifier.semantics(mergeDescendants = true) { contentDescription = "Searching" }) { repeat(3) { SkeletonRow() } }
            }
            searched && results.isEmpty() -> InfoBanner("No books found. Check the spelling, or try the author’s name.")
            else -> Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                results.forEach { book -> CandidateRow(book, selected = false, Modifier.pressable { onPick(book, results) }) }
            }
        }
    }
}

/** One edition row. Selected: soft2 fill, accent border and a check. */
@Composable
fun CandidateRow(candidate: BookCandidate, selected: Boolean, modifier: Modifier = Modifier) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.field + 2.dp)
    Row(
        modifier.fillMaxWidth().clip(shape).background(if (selected) c.soft2 else Color.Transparent)
            .border(QsSize.stroke, if (selected) c.accent else c.line, shape)
            .semantics(mergeDescendants = true) { this.selected = selected }
            .padding(QsSpace.s12),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        BookCover(null, candidate.title, width = 44.dp, url = candidate.coverUrl)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
            Text(candidate.title, style = QsType.body.semibold(), color = c.ink)
            Text(listOfNotNull(candidate.author, candidate.detail).filter { it.isNotEmpty() }.joinToString(" · "), style = QsType.footnote, color = c.ink2)
        }
        if (selected) QsIcon(R.drawable.ic_qs_check, tint = c.accentInk, size = QsSize.iconM + 2.dp)
    }
}

// MARK: Is this the book? (Flow 2 › Step 4)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConfirmEditionSheet(candidates: List<BookCandidate>, photo: Bitmap?, onDismiss: () -> Unit, onAdded: () -> Unit) {
    val c = QsTheme.colors
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    val online = rememberIsOnline()
    var selected by remember { mutableStateOf(candidates.firstOrNull()?.id) }
    var usePhoto by remember { mutableStateOf(true) }
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    fun add(status: ReadingStatus) {
        val pick = candidates.firstOrNull { it.id == selected } ?: candidates.firstOrNull() ?: return
        AppScope.launch {
            BookAdder.add(env, notifier, pick.title, pick.author, pick.isbn, pick.pageCount, status,
                if (usePhoto) photo else null, pick.coverUrl, online)
        }
        onAdded()
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = state, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8),
                verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
            ) {
                Text("Is this the book?", style = QsTheme.headline(24), color = c.ink, modifier = Modifier.semantics { heading() })
                candidates.forEach { cand ->
                    CandidateRow(cand, selected == cand.id, Modifier.pressable(role = Role.RadioButton) { selected = cand.id })
                }
                if (photo != null) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).pressable(role = Role.Switch) { usePhoto = !usePhoto },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Use my photo as the cover", style = QsType.body, color = c.ink, modifier = Modifier.weight(1f))
                        Switch(usePhoto, { usePhoto = it }, colors = SwitchDefaults.colors(checkedTrackColor = c.accent, checkedThumbColor = c.onAccent))
                    }
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(horizontal = QsSpace.s20).padding(top = QsSpace.s12, bottom = QsSpace.s24),
                verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
            ) {
                QsButton("Add to Reading now", { add(ReadingStatus.Reading) })
                QsButton("Add to Want to read", { add(ReadingStatus.ToRead) }, kind = QsButtonKind.Secondary)
            }
        }
    }
}

// MARK: We couldn't find this book (Flow 2 › No match) / Add by hand

@Composable
private fun NoMatchScreen(n: NoMatch, onBack: () -> Unit, onDone: () -> Unit) {
    val c = QsTheme.colors
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    val online = rememberIsOnline()
    val scope = rememberCoroutineScope()
    var title by rememberSaveable { mutableStateOf(n.title) }
    var author by rememberSaveable { mutableStateOf(n.author) }
    var searching by remember { mutableStateOf(false) }
    var results by remember { mutableStateOf<List<BookCandidate>?>(null) }
    LaunchedEffect(Unit) {
        if (n.showsWarning) notifier.show("No match for this cover", "Try the barcode, or add the book yourself.", NoticeKind.Warning)
    }
    FlowScreen(
        title = null, onBack = onBack,
        actions = {
            QsButton(if (searching) "Searching…" else "Search again", {
                scope.launch {
                    searching = true
                    val found = BookSearch.search("$title $author")
                    searching = false
                    if (found.isEmpty()) notifier.show("Still no match", "You can add it as it is. Details can be changed later.", NoticeKind.Warning)
                    else results = found
                }
            }, enabled = !searching && title.isNotBlank())
            QsButton(if (n.photo == null) "Add as I typed it" else "Add with my photo", {
                AppScope.launch {
                    BookAdder.add(env, notifier, title.trim(), author.trim(), null, null, ReadingStatus.ToRead, n.photo, null, online)
                }
                onDone()
            }, kind = QsButtonKind.Secondary, enabled = title.isNotBlank())
        },
    ) {
        Text(n.heading, style = QsTheme.headline(28), color = c.ink, modifier = Modifier.semantics { heading() })
        if (n.photo != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
                Image(n.photo.asImageBitmap(), null, contentScale = ContentScale.Crop,
                    modifier = Modifier.size(QsSize.coverM, QsSize.coverM * 1.5f).clip(RoundedCornerShape(QsTheme.shapes.cover)))
                Secondary("Your photo will be the cover.")
            }
        }
        QsTextField(title, { title = it }, "Title", label = "Title", capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next)
        QsTextField(author, { author = it }, "Author", label = "Author", capitalization = KeyboardCapitalization.Words)
    }
    results?.let { r -> ConfirmEditionSheet(r.take(3), n.photo, onDismiss = { results = null }, onAdded = { results = null; onDone() }) }
}

// MARK: Adding

object BookAdder {
    /** Saves the book straight away (works offline); the cover fills in later when it's online. */
    suspend fun add(
        env: AppEnvironment, notifier: Notifier, title: String, author: String, isbn: String?, pageCount: Int?,
        status: ReadingStatus, photo: Bitmap?, coverUrl: String?, isOnline: Boolean = true,
    ): Long? {
        val existing = env.library.books.first()
        if (existing.any { it.matchKey == Book.matchKey(title, author, isbn) }) {
            notifier.show("Already on your shelf", "“$title” is in your library.", NoticeKind.Info)
            return null
        }
        val coverFile = photo?.let { env.covers.save(it) }
        val id = env.library.add(BookEntity(title = title, author = author, isbn = isbn, pageCount = pageCount, status = status.raw, coverFile = coverFile))
        val shelf = if (status == ReadingStatus.Reading) "Reading now" else status.shelfName
        // Flow 10 › C2 · Book added offline
        val message = if (isOnline || coverFile != null) "“$title” is on $shelf." else "Its cover and details will fill in when you’re back online."
        notifier.show("Book added", message, actionTitle = "Undo") {
            AppScope.launch { env.library.dao.book(id)?.let { env.library.delete(Book(it)) } }
        }
        if (coverFile == null) {
            val bytes = BookSearch.coverBytes(isbn, coverUrl)
            val name = bytes?.let { env.covers.save(it) }
            if (name != null) env.library.dao.book(id)?.let { env.library.dao.update(it.copy(coverFile = name)) }
        }
        return id
    }
}
