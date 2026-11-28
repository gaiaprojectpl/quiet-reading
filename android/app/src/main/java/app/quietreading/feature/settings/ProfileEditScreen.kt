package app.quietreading.feature.settings

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.quietreading.R
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.components.BookCover
import app.quietreading.designsystem.components.FlowScreen
import app.quietreading.designsystem.components.QsButton
import app.quietreading.designsystem.components.QsButtonKind
import app.quietreading.designsystem.components.QsButtonSize
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListCard
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.semibold
import kotlinx.coroutines.launch

/** Flow 4 › Edit profile: photo, display name, account name, about me, show my name on widgets. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileEditScreen(onClose: () -> Unit) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val env = LocalApp.current
    val scope = rememberCoroutineScope()
    val books by env.library.books.collectAsState(initial = emptyList())
    val withCovers = books.filter { it.coverFile != null }

    var loaded by remember { mutableStateOf(false) }
    var saved by remember { mutableStateOf(listOf("", "", "")) }
    var savedWidgets by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var handle by remember { mutableStateOf("") }
    var about by remember { mutableStateOf("") }
    var showOnWidgets by remember { mutableStateOf(false) }
    val original = remember { Avatar.load(context) }
    var photo by remember { mutableStateOf(original) }

    var photoMenu by remember { mutableStateOf(false) }
    var choosingCover by remember { mutableStateOf(false) }
    var cameraBlocked by remember { mutableStateOf(false) }
    var confirmDiscard by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val p = env.prefs
        saved = listOf(p.get(Keys.name, ""), p.get(Keys.handle, ""), p.get(Keys.about, ""))
        savedWidgets = p.get(Keys.showOnWidgets, false)
        name = saved[0]; handle = saved[1]; about = saved[2]; showOnWidgets = savedWidgets
        loaded = true
    }

    val handleValid = handle.all { it.isLetterOrDigit() || it == '.' || it == '_' }
    val hasChanges = loaded && (listOf(name, handle, about) != saved || showOnWidgets != savedWidgets || photo !== original)
    val leave = { if (hasChanges) confirmDiscard = true else onClose() }
    BackHandler(onBack = leave)

    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bmp: Bitmap? ->
        if (bmp != null) photo = bmp.asImageBitmap()
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) camera.launch(null) else cameraBlocked = true
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) decode(context, uri)?.let { photo = it.asImageBitmap() }
    }

    FlowScreen(
        "Edit profile", onBack = leave, backLabel = "Cancel", closeInstead = true,
        actions = {
            QsButton("Save", {
                scope.launch {
                    val p = env.prefs
                    p.set(Keys.name, name.trim())
                    p.set(Keys.handle, handle.trim().lowercase())
                    p.set(Keys.about, about.trim())
                    p.set(Keys.showOnWidgets, showOnWidgets)
                    if (photo !== original) Avatar.save(context, photo?.asAndroidBitmap())
                    onClose()   // saving is silent
                }
            }, enabled = hasChanges && handleValid)
        },
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            Box(contentAlignment = Alignment.BottomEnd) {
                AvatarView(photo, name, 96.dp)
                Box(Modifier.size(28.dp).background(c.accent, CircleShape).border(2.dp, c.bg, CircleShape), contentAlignment = Alignment.Center) {
                    QsIcon(R.drawable.ic_qs_camera, tint = c.onAccent, size = QsSize.iconS)
                }
            }
            Box(Modifier.heightIn(min = QsSize.touchAndroid).pressable { photoMenu = true }.padding(horizontal = QsSpace.s12), contentAlignment = Alignment.Center) {
                Text("Change photo", style = QsType.subheadline.semibold(), color = c.accentInk)
            }
        }
        QsTextField("Display name", name, { name = it }, keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Words))
        Column(verticalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            QsTextField("Account name", handle, { handle = it }, prefix = "@", error = !handleValid)
            Text(
                if (handleValid) "Shown on shared shelves. Letters, numbers, dots." else "Use letters, numbers and dots only.",
                style = QsType.footnote, color = if (handleValid) c.ink2 else c.error,
            )
        }
        QsTextField("About me", about, { about = it }, singleLine = false, keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences))
        QsListCard(rows = listOf({ ToggleRow(null, "Show my name on widgets", checked = showOnWidgets) { showOnWidgets = it } }))
    }

    if (photoMenu) ModalBottomSheet(
        onDismissRequest = { photoMenu = false }, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        SheetBody("Profile photo", actions = { QsButton("Cancel", { photoMenu = false }, kind = QsButtonKind.Text) }) {
            val hasCamera = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
            if (hasCamera) QsButton("Take photo", {
                photoMenu = false
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) camera.launch(null)
                else cameraPermission.launch(Manifest.permission.CAMERA)
            }, kind = QsButtonKind.Outline)
            QsButton("Choose from library", {
                photoMenu = false
                gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }, kind = QsButtonKind.Outline)
            if (withCovers.isNotEmpty()) QsButton("Use a book cover", { photoMenu = false; choosingCover = true }, kind = QsButtonKind.Outline)
            if (photo != null) QsButton("Remove photo", { photoMenu = false; photo = null }, kind = QsButtonKind.Destructive, size = QsButtonSize.Small)
        }
    }

    if (choosingCover) ModalBottomSheet(
        onDismissRequest = { choosingCover = false }, containerColor = c.surface,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(topStart = QsTheme.shapes.sheet, topEnd = QsTheme.shapes.sheet),
    ) {
        Column(Modifier.padding(horizontal = QsSpace.s20).padding(bottom = QsSpace.s24), verticalArrangement = Arrangement.spacedBy(QsSpace.s16)) {
            Text("Use a book cover", style = QsTheme.headline(22), color = c.ink)
            LazyVerticalGrid(GridCells.Fixed(3), horizontalArrangement = Arrangement.spacedBy(QsSpace.s12), verticalArrangement = Arrangement.spacedBy(QsSpace.s12)) {
                items(withCovers, key = { it.id }) { book ->
                    BookCover(book.coverFile, book.title, width = null, modifier = Modifier.semantics { contentDescription = book.title }.pressable(label = book.title) {
                        BitmapFactory.decodeFile(env.covers.file(book.coverFile!!).path)?.let { photo = it.asImageBitmap() }
                        choosingCover = false
                    })
                }
            }
        }
    }

    if (cameraBlocked) QsDialog(
        "Allow camera access?",
        "Quiet Reading uses the camera only for your photo. It stays on this phone. You can also choose one from your library.",
        "Open settings", {
            cameraBlocked = false
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        "Not now", { cameraBlocked = false },
    )
    // Flow 4 › Unsaved changes
    if (confirmDiscard) QsDialog(
        "Discard your changes?", "Your profile stays as it was.",
        "Discard", { confirmDiscard = false; onClose() },
        "Keep editing", { confirmDiscard = false }, destructive = true,
    )
}

private fun decode(context: android.content.Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= 28) ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { d, info, _ ->
        d.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        d.setTargetSampleSize(maxOf(1, maxOf(info.size.width, info.size.height) / 1024))
    } else @Suppress("DEPRECATION") MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
}.getOrNull()
