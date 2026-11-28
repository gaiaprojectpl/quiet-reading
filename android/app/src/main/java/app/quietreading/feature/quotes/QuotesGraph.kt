package app.quietreading.feature.quotes

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.data.Book
import app.quietreading.data.LocalApp
import app.quietreading.data.QuoteEntity
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.ChipFlow
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.InfoBanner
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsChip
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsIconButton
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.medium
import app.quietreading.feature.stats.NumberField
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.concurrent.Executors
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.min

/** Flow 9 · Add a quote: Photograph the page → Select lines → New quote → Saved. */
object QuoteRoutes {
    const val ADD = "quotes/add/{bookId}?source={source}"
    /** [source] = "photo", "typed" or null (ask first). */
    fun add(bookId: Long, source: String? = null) = "quotes/add/$bookId" + (source?.let { "?source=$it" } ?: "")
}

fun NavGraphBuilder.quotesGraph(nav: AppNav) {
    composable(
        QuoteRoutes.ADD,
        arguments = listOf(
            navArgument("bookId") { type = NavType.LongType },
            navArgument("source") { type = NavType.StringType; nullable = true; defaultValue = null },
        ),
    ) { entry ->
        AddQuoteScreen(nav, entry.arguments?.getLong("bookId") ?: 0L, entry.arguments?.getString("source"))
    }
}

/** What the reader is adding: text (read from a photo or typed) and the page. */
data class QuoteDraft(val text: String, val page: Int?, val fromPhoto: Boolean)

/** The camera screens mimic the system camera: dark, whatever the theme (Figma c/system/camera). */
private object CameraColors {
    val background = Color(0xFF000000)
    val viewfinder = Color(0xFF1A1A1A)
    val onCamera = Color(0xFFFFFFFF)
    val pill = Color(0x99000000)
}

@Composable
private fun AddQuoteScreen(nav: AppNav, bookId: Long, source: String?) {
    val books by LocalApp.current.library.books.collectAsState(initial = null)
    val book = books?.firstOrNull { it.id == bookId }
    var mode by remember { mutableStateOf(source) }
    var draft by remember { mutableStateOf<QuoteDraft?>(null) }
    if (books != null && book == null) { LaunchedEffect(Unit) { nav.back() }; return }
    if (book == null) return

    when {
        draft != null -> QuoteEditorScreen(book, draft!!, onDone = nav::back)
        mode == "photo" -> PageScanner(
            onUse = { text, page -> draft = QuoteDraft(text, page, fromPhoto = true) },
            onType = { mode = "typed" },
            onCancel = nav::back,
        )
        else -> {
            // Ask first, then the typed quote opens as a sheet (like notes).
            FlowScreen("Add a quote", onBack = nav::back) {
                AddQuoteChoices(onPhoto = { mode = "photo" }, onTyped = { mode = "typed" })
            }
            if (mode == "typed") QuoteEditorSheet(book, onDone = nav::back, onDismiss = { if (source == "typed") nav.back() else mode = null })
        }
    }
}

/** Step 2 · the two ways to add a quote. Also usable inside a sheet on book details. */
@Composable
fun AddQuoteChoices(onPhoto: () -> Unit, onTyped: () -> Unit) {
    QsListCard(rows = listOf(
        { QsListRow(R.drawable.ic_qs_barcode, "Photograph the page", "Select the lines. Text is read on your phone.", onClick = onPhoto) },
        { QsListRow(R.drawable.ic_qs_quote, "Type or paste", onClick = onTyped) },
    ))
}

/** Step 2 as a bottom sheet, for book details: "Add a quote" with the two choices. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddQuoteSheet(nav: AppNav, bookId: Long, onDismiss: () -> Unit) {
    val c = QsTheme.colors
    ModalBottomSheet(onDismiss, containerColor = c.surface, shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet)) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(bottom = QsSpace.s24), verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            Text("Add a quote", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
            AddQuoteChoices(
                onPhoto = { onDismiss(); nav.controller.navigate(QuoteRoutes.add(bookId, "photo")) },
                onTyped = { onDismiss(); nav.controller.navigate(QuoteRoutes.add(bookId, "typed")) },
            )
        }
    }
}

// Step 3 · Photograph the page + select lines

@Composable
private fun PageScanner(onUse: (String, Int?) -> Unit, onType: () -> Unit, onCancel: () -> Unit) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var asked by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it; asked = true }
    LaunchedEffect(Unit) { if (!granted) permission.launch(Manifest.permission.CAMERA) }

    val capture = remember { ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build() }
    var camera by remember { mutableStateOf<Camera?>(null) }
    var torch by remember { mutableStateOf(false) }
    var photo by remember { mutableStateOf<Bitmap?>(null) }
    var lines by remember { mutableStateOf<List<PageReader.Line>>(emptyList()) }
    var page by remember { mutableStateOf<Int?>(null) }
    var selected by remember { mutableStateOf(setOf<Int>()) }
    var reading by remember { mutableStateOf(false) }
    var noText by remember { mutableStateOf(false) }

    fun read(bitmap: Bitmap) {
        reading = true
        photo = bitmap
        scope.launch {
            val r = PageReader.read(bitmap)
            reading = false
            lines = r.lines
            page = r.page
            noText = r.lines.isEmpty()
        }
    }

    Column(
        Modifier.fillMaxSize().background(CameraColors.background).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.heightIn(min = QsSize.touchAndroid).toggleable(false, role = Role.Button) { onCancel() }, contentAlignment = Alignment.Center) {
                Text("Cancel", style = QsType.body.medium(), color = CameraColors.onCamera)
            }
            Box(Modifier.weight(1f))
            if (camera?.cameraInfo?.hasFlashUnit() == true && photo == null) {
                QsIconButton(R.drawable.ic_qs_flash, if (torch) "Turn off the flash" else "Turn on the flash", tint = if (torch) c.warningSoft else CameraColors.onCamera) {
                    torch = !torch
                    camera?.cameraControl?.enableTorch(torch)
                }
            }
        }
        // Page area
        Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(QsTheme.shapes.sheet)).background(CameraColors.viewfinder), contentAlignment = Alignment.Center) {
            val shot = photo
            when {
                shot != null -> SelectableLines(shot, lines, selected) { i ->
                    haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                    selected = if (i in selected) selected - i else selected + i
                }
                granted -> CameraPreview(capture) { camera = it }
                else -> Text(
                    if (asked) "The camera is off for Quiet Reading. Turn it on in Settings, or type the quote instead." else "The camera isn’t available here. Type the quote instead.",
                    style = QsType.subheadline, color = CameraColors.onCamera.copy(alpha = 0.8f), textAlign = TextAlign.Center, modifier = Modifier.padding(QsSpace.s24),
                )
            }
        }
        // Status pill
        val count = selected.size
        val (status, isError) = when {
            noText -> "No text found. Hold the book flat, in good light." to true
            reading -> "Reading the page…" to false
            photo != null -> ((if (count == 0) "Tap the lines you want" else if (count == 1) "1 line selected" else "$count lines selected") +
                (page?.let { " · page $it found" } ?: "")) to false
            else -> "Fill the frame with the page" to false
        }
        Row(
            Modifier.align(Alignment.CenterHorizontally).background(if (isError) c.error else CameraColors.pill, CircleShape)
                .padding(horizontal = QsSpace.s16, vertical = QsSpace.s8).semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(QsSpace.s8),
        ) {
            QsIcon(if (isError) R.drawable.ic_qs_alert else R.drawable.ic_qs_barcode, tint = CameraColors.onCamera, size = QsSize.iconS)
            Text(status, style = QsType.subheadline.medium(), color = CameraColors.onCamera)
        }
        // Actions
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
            when {
                noText -> QsButton("Try again", { photo = null; noText = false; lines = emptyList(); selected = emptySet() })
                photo != null -> QsButton("Use selection", {
                    onUse(selected.sorted().joinToString(" ") { lines[it].text }, page)
                }, enabled = selected.isNotEmpty())
                else -> QsButton("Take photo", {
                    scope.launch { takePicture(capture)?.let(::read) }
                }, enabled = granted && !reading)
            }
            QsButton("Type it instead", onType, kind = QsButtonKind.Text)
        }
    }
    DisposableEffect(Unit) { onDispose { camera?.cameraControl?.enableTorch(false) } }
}

@Composable
private fun CameraPreview(capture: ImageCapture, onCamera: (Camera) -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    AndroidView(
        factory = { ctx ->
            PreviewView(ctx).also { view ->
                view.scaleType = PreviewView.ScaleType.FILL_CENTER
                val future = ProcessCameraProvider.getInstance(ctx)
                future.addListener({
                    runCatching {
                        val provider = future.get()
                        val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                        provider.unbindAll()
                        onCamera(provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, capture))
                    }
                }, ContextCompat.getMainExecutor(context))
            }
        },
        modifier = Modifier.fillMaxSize().semantics { contentDescription = "Camera. Fill the frame with the page." },
    )
}

private suspend fun takePicture(capture: ImageCapture): Bitmap? = suspendCancellableCoroutine { cont ->
    val executor = Executors.newSingleThreadExecutor()
    capture.takePicture(executor, object : ImageCapture.OnImageCapturedCallback() {
        override fun onCaptureSuccess(image: ImageProxy) {
            val bitmap = runCatching {
                val raw = image.toBitmap()
                val rotation = image.imageInfo.rotationDegrees
                if (rotation == 0) raw else Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, Matrix().apply { postRotate(rotation.toFloat()) }, true)
            }.getOrNull()
            image.close()
            executor.shutdown()
            if (cont.isActive) cont.resume(bitmap)
        }
        override fun onError(exception: ImageCaptureException) {
            executor.shutdown()
            if (cont.isActive) cont.resume(null)
        }
    })
}

/** The photo with each read line as a tappable band; selected lines are filled in accent. */
@Composable
private fun SelectableLines(photo: Bitmap, lines: List<PageReader.Line>, chosen: Set<Int>, onTap: (Int) -> Unit) {
    val c = QsTheme.colors
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val boxW = with(density) { maxWidth.toPx() }
        val boxH = with(density) { maxHeight.toPx() }
        val scale = min(boxW / photo.width, boxH / photo.height)
        val left = (boxW - photo.width * scale) / 2
        val top = (boxH - photo.height * scale) / 2
        Image(photo.asImageBitmap(), null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
        lines.forEachIndexed { i, line ->
            val x = left + line.box.left * scale
            val y = top + line.box.top * scale
            val w = line.box.width() * scale
            val h = max(line.box.height() * scale, with(density) { (QsSize.touchAndroid / 2).toPx() })
            val isOn = i in chosen
            Box(
                Modifier
                    .offset(with(density) { x.toDp() }, with(density) { y.toDp() })
                    .size(with(density) { w.toDp() }, with(density) { h.toDp() })
                    .background(if (isOn) c.accent.copy(alpha = 0.85f) else Color.Transparent)
                    .toggleable(isOn, role = Role.Checkbox) { onTap(i) }
                    .semantics { contentDescription = line.text; selected = isOn },
            )
        }
    }
}

// Step 4 · New quote + Step 5 · Saved

private val MOODS = listOf("Hopeful", "Cozy", "Sad", "Funny")

/** Photo quotes stay full screen: the read text, page, mood and widget toggle. */
@Composable
private fun QuoteEditorScreen(book: Book, draft: QuoteDraft, onDone: () -> Unit) {
    val state = rememberQuoteState(book, draft)
    FlowScreen(
        "New quote", onBack = onDone, backLabel = "Cancel", closeInstead = true,
        actions = { QsButton("Save", { state.save(onDone) }, enabled = state.canSave) },
    ) { QuoteFields(state, draft) }
}

/** Typed quotes open as a sheet, like notes. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuoteEditorSheet(book: Book, onDone: () -> Unit, onDismiss: () -> Unit = onDone) {
    val c = QsTheme.colors
    val draft = remember { QuoteDraft("", book.currentPage.takeIf { it > 0 }, fromPhoto = false) }
    val state = rememberQuoteState(book, draft)
    ModalBottomSheet(
        onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.surface, shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = QsSpace.s20).padding(bottom = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            Text("New quote", style = QsTheme.headline(22), color = c.ink, modifier = Modifier.semantics { heading() })
            QuoteFields(state, draft)
            QsButton("Save", { state.save(onDone) }, enabled = state.canSave)
        }
    }
}

private class QuoteState(val save: (() -> Unit) -> Unit) {
    var text by mutableStateOf("")
    var page by mutableStateOf("")
    var mood by mutableStateOf<String?>(null)
    var showOnWidget by mutableStateOf(true)
    val canSave get() = text.isNotBlank()
}

@Composable
private fun rememberQuoteState(book: Book, draft: QuoteDraft): QuoteState {
    val library = LocalApp.current.library
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    lateinit var state: QuoteState
    state = remember {
        QuoteState { done ->
            scope.launch {
                library.addQuote(QuoteEntity(
                    bookId = book.id, text = state.text.trim(), page = state.page.toIntOrNull(), mood = state.mood,
                    showOnWidget = state.showOnWidget, fromPhoto = draft.fromPhoto,
                ))
                notifier.show("Quote saved", "It’s in your quotes.")
                done()
            }
        }.also { it.text = draft.text; it.page = draft.page?.toString() ?: "" }
    }
    return state
}

@Composable
private fun QuoteFields(state: QuoteState, draft: QuoteDraft) {
    val c = QsTheme.colors
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (draft.text.isEmpty()) runCatching { focus.requestFocus() } }
    val pageMissing = draft.fromPhoto && state.page.isEmpty()
    if (state.text.length > 140) InfoBanner("Long quotes are fine. The widget shows the first 140 characters.")
    Labeled("Quote") {
        val shape = RoundedCornerShape(QsTheme.shapes.field)
        BasicTextField(
            state.text, { state.text = it },
            modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp).focusRequester(focus).background(c.surface, shape)
                .border(QsSize.stroke, c.lineStrong, shape).padding(QsSpace.s16).semantics { contentDescription = "Quote" },
            textStyle = QsTheme.headline(17).copy(color = c.ink),
            cursorBrush = SolidColor(c.accent),
            decorationBox = { inner -> Box { if (state.text.isEmpty()) Text("Quote", style = QsTheme.headline(17), color = c.ink2); inner() } },
        )
        if (draft.fromPhoto) Text("Read from your photo. Fix anything we got wrong.", style = QsType.footnote, color = c.ink2)
    }
    Labeled("Page") {
        NumberField(state.page, { state.page = it }, "Page", error = pageMissing)
        if (pageMissing) {
            Row(horizontalArrangement = Arrangement.spacedBy(QsSpace.s4), verticalAlignment = Alignment.CenterVertically) {
                QsIcon(R.drawable.ic_qs_alert, tint = c.error, size = QsSize.iconS)
                Text("We couldn’t see a page number. Type it.", style = QsType.footnote, color = c.error)
            }
        } else if (draft.fromPhoto && draft.page != null && state.page == draft.page.toString()) {
            Text("Found on the photo", style = QsType.footnote, color = c.ink2)
        }
    }
    Labeled("How did it feel?") {
        ChipFlow {
            MOODS.forEach { m -> QsChip(m, state.mood == m) { state.mood = if (state.mood == m) null else m } }
        }
    }
    Row(
        Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid)
            .toggleable(state.showOnWidget, role = Role.Switch) { state.showOnWidget = it },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Show on my quote widget", style = QsType.body, color = c.ink, modifier = Modifier.weight(1f))
        Switch(
            state.showOnWidget, null,
            colors = SwitchDefaults.colors(checkedTrackColor = c.accent, checkedThumbColor = c.onAccent, uncheckedBorderColor = c.lineStrong, uncheckedThumbColor = c.lineStrong, uncheckedTrackColor = c.surface),
        )
    }
}

@Composable
private fun Labeled(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
        Text(label, style = QsType.footnote.medium(), color = QsTheme.colors.ink2)
        content()
    }
}
