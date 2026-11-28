package app.quietreading.designsystem.components

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.quietreading.data.BookSearch
import app.quietreading.data.LocalApp
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap

private val memory = ConcurrentHashMap<String, ImageBitmap>()

/** Loads a stored cover file (cached in memory). */
@Composable
fun rememberCover(file: String?): ImageBitmap? {
    val covers = LocalApp.current.covers
    val image by produceState(file?.let { memory[it] }, file) {
        if (file == null) { value = null; return@produceState }
        value = memory[file] ?: withContext(Dispatchers.IO) {
            BitmapFactory.decodeFile(covers.file(file).path)?.asImageBitmap()?.also { memory[file] = it }
        }
    }
    return image
}

/** Loads a cover from the web (search results, Astrid's picks). */
@Composable
fun rememberRemoteImage(url: String?): ImageBitmap? {
    val image by produceState(url?.let { memory[it] }, url) {
        if (url == null) { value = null; return@produceState }
        value = memory[url] ?: BookSearch.download(url)?.let { bytes ->
            withContext(Dispatchers.Default) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }
        }?.also { memory[url] = it }
    }
    return image
}

/**
 * A book cover at 2:3 with the theme's cover radius and a soft shadow.
 * Without an image it shows a calm placeholder with the title (covers fill in later).
 * [width] null = fill the available width (grid tiles).
 */
@Composable
fun BookCover(file: String?, title: String, modifier: Modifier = Modifier, width: Dp? = QsSize.coverM, url: String? = null) {
    val local = rememberCover(file)
    val remote = if (local == null && url != null) rememberRemoteImage(url) else null
    CoverFrame(local ?: remote, title, modifier, width)
}

@Composable
fun CoverFrame(image: ImageBitmap?, title: String, modifier: Modifier = Modifier, width: Dp? = QsSize.coverM) {
    val c = QsTheme.colors
    val shape = RoundedCornerShape(QsTheme.shapes.cover)
    val sized = if (width != null) modifier.size(width, width * 1.5f) else modifier.fillMaxWidth().aspectRatio(2f / 3f)
    Box(
        sized.shadow(3.dp, shape, ambientColor = Color.Black.copy(alpha = 0.16f), spotColor = Color.Black.copy(alpha = 0.16f))
            .clip(shape).background(c.disabledBg).clearAndSetSemantics {},
        contentAlignment = Alignment.Center,
    ) {
        if (image != null) {
            Image(image, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Text(title, style = QsType.caption2, color = c.ink2, textAlign = TextAlign.Center, modifier = Modifier.padding(QsSpace.s4))
        }
    }
}
