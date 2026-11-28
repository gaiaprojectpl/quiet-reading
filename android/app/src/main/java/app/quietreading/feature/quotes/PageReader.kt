package app.quietreading.feature.quotes

import android.graphics.Bitmap
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/** Reads a page photo on the phone (ML Kit, on-device): text lines with their positions, and the page number if printed. */
object PageReader {
    data class Line(val text: String, /** Position in the photo, in pixels. */ val box: Rect)
    data class Result(val lines: List<Line>, val page: Int?)

    suspend fun read(bitmap: Bitmap): Result = suspendCancellableCoroutine { cont ->
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { text ->
                val lines = mutableListOf<Line>()
                var page: Int? = null
                val h = bitmap.height
                for (block in text.textBlocks) for (line in block.lines) {
                    val t = line.text.trim()
                    val box = line.boundingBox ?: continue
                    if (t.isEmpty()) continue
                    // A lone number near the top or bottom edge is the page number.
                    val n = t.toIntOrNull()
                    if (n != null && n in 1..4999 && (box.bottom > h * 0.88 || box.top < h * 0.12)) page = n
                    else lines += Line(t, box)
                }
                lines.sortBy { it.box.top }   // top to bottom
                recognizer.close()
                if (cont.isActive) cont.resume(Result(lines, page))
            }
            .addOnFailureListener {
                recognizer.close()
                if (cont.isActive) cont.resume(Result(emptyList(), null))
            }
    }
}
