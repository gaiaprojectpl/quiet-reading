package app.quietreading.feature.add

import android.graphics.Bitmap
import android.graphics.Color as AColor
import android.graphics.Matrix
import androidx.annotation.OptIn
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.concurrent.Executors
import kotlin.coroutines.resume

/** Camera colours come from Figma's c/system variables (the same in every theme, not app tokens). */
object QsSystemColor {
    val camera = Color(0xFF141414)     // c/system/camera
    val viewfinder = Color(0xFF2A2A2A)
    val onCamera = Color.White         // c/system/onCamera
}

/** Talks to the running camera: photo capture and the torch. */
class CameraController {
    internal var capture: ImageCapture? = null
    internal var camera: Camera? = null
    var torchOn by mutableStateOf(false)
        private set

    fun toggleTorch() {
        val cam = camera ?: return
        if (!cam.cameraInfo.hasFlashUnit()) return
        torchOn = !torchOn
        cam.cameraControl.enableTorch(torchOn)
    }

    /** Takes a photo, upright. */
    suspend fun capturePhoto(context: android.content.Context): Bitmap? {
        val ic = capture ?: return null
        return suspendCancellableCoroutine { cont ->
            ic.takePicture(ContextCompat.getMainExecutor(context), object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    val rotation = image.imageInfo.rotationDegrees
                    val bitmap = runCatching { image.toBitmap() }.getOrNull()
                    image.close()
                    val upright = bitmap?.let {
                        if (rotation == 0) it else Bitmap.createBitmap(it, 0, 0, it.width, it.height, Matrix().apply { postRotate(rotation.toFloat()) }, true)
                    }
                    if (cont.isActive) cont.resume(upright)
                }
                override fun onError(exception: ImageCaptureException) { if (cont.isActive) cont.resume(null) }
            })
        }
    }
}

/**
 * Live camera for Flow 2 (CameraX). Cover: preview + photo capture; Barcode: reads EAN-13 ISBNs
 * continuously with ML Kit, on the phone.
 */
@OptIn(ExperimentalGetImage::class)
@Composable
fun CameraView(barcode: Boolean, controller: CameraController, onISBN: (String) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val onIsbn by rememberUpdatedState(onISBN)
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER; setBackgroundColor(AColor.rgb(0x2A, 0x2A, 0x2A)) } }
    DisposableEffect(barcode) {
        val executor = Executors.newSingleThreadExecutor()
        val scanner = BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_EAN_13).build())
        var reported: String? = null
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            val provider = runCatching { future.get() }.getOrNull() ?: return@addListener
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            val useCases = mutableListOf<androidx.camera.core.UseCase>(preview)
            if (barcode) {
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { proxy ->
                    val media = proxy.image
                    if (media == null) { proxy.close(); return@setAnalyzer }
                    scanner.process(InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees))
                        .addOnSuccessListener { codes ->
                            codes.mapNotNull { it.rawValue }
                                .firstOrNull { it.length == 13 && (it.startsWith("978") || it.startsWith("979")) && it != reported }
                                ?.let { reported = it; onIsbn(it) }
                        }
                        .addOnCompleteListener { proxy.close() }
                }
                useCases += analysis
                controller.capture = null
            } else {
                val ic = ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
                useCases += ic
                controller.capture = ic
            }
            runCatching {
                provider.unbindAll()
                controller.camera = provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, *useCases.toTypedArray())
            }
        }, ContextCompat.getMainExecutor(context))
        onDispose {
            runCatching { future.get().unbindAll() }
            controller.camera = null
            controller.capture = null
            scanner.close()
            executor.shutdown()
        }
    }
    AndroidView({ previewView }, modifier)
}

/** Reading the cover on the phone (ML Kit text recognition). */
object CoverReader {
    data class Result(
        /** Biggest lines first – usually the title, then the author. */
        val lines: List<String>,
        val isTooDark: Boolean,
    ) { val query get() = lines.take(2).joinToString(" ") }

    suspend fun read(bitmap: Bitmap): Result {
        val dark = averageBrightness(bitmap) < 0.12
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val lines: List<String> = suspendCancellableCoroutine { cont ->
            recognizer.process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { text ->
                    val all = text.textBlocks.flatMap { it.lines }
                        .filter { (it.confidence.takeIf { c -> c > 0f } ?: 1f) > 0.3f }
                        .sortedByDescending { it.boundingBox?.height() ?: 0 }
                        .map { it.text.trim() }
                        .filter { it.length > 1 }
                    if (cont.isActive) cont.resume(all.take(4))
                }
                .addOnFailureListener { if (cont.isActive) cont.resume(emptyList()) }
        }
        recognizer.close()
        return Result(lines, dark && lines.isEmpty())
    }

    private fun averageBrightness(b: Bitmap): Double {
        val small = Bitmap.createScaledBitmap(b, 16, 16, true)
        var sum = 0.0
        for (x in 0 until 16) for (y in 0 until 16) {
            val p = small.getPixel(x, y)
            sum += (0.299 * AColor.red(p) + 0.587 * AColor.green(p) + 0.114 * AColor.blue(p)) / 255
        }
        return sum / 256
    }
}

/**
 * Turns a photo of a book into a cover: a centred 2:3 crop (on the phone).
 * iOS also straightens the book's rectangle with Vision; ML Kit has no rectangle detector, so Android crops only.
 */
object CoverCropper {
    fun crop(b: Bitmap): Bitmap {
        val w = b.width.toFloat(); val h = b.height.toFloat()
        val tw = minOf(w, h * 2 / 3); val th = tw * 3 / 2
        return Bitmap.createBitmap(b, ((w - tw) / 2).toInt(), ((h - th) / 2).toInt().coerceAtLeast(0), tw.toInt(), th.toInt().coerceAtMost(b.height))
    }
}
