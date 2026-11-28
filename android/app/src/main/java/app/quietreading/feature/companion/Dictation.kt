package app.quietreading.feature.companion

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Mic in the composer: speech to text with Android's recogniser (on-device when the phone offers it).
 * Audio is never stored. Call from the main thread.
 */
class Dictation(private val context: Context) {
    enum class State { Idle, Listening, Denied, Unavailable }

    var state by mutableStateOf(State.Idle)
        private set
    var text by mutableStateOf("")
        private set
    private var recognizer: SpeechRecognizer? = null

    val isListening get() = state == State.Listening

    fun denied() { state = State.Denied }

    fun start() {
        if (isListening) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) { state = State.Unavailable; return }
        text = ""
        val r = recognizer ?: SpeechRecognizer.createSpeechRecognizer(context).also { recognizer = it }
        r.setRecognitionListener(object : RecognitionListener {
            override fun onPartialResults(partialResults: Bundle?) { best(partialResults)?.let { text = it } }
            override fun onResults(results: Bundle?) { best(results)?.let { text = it }; state = State.Idle }
            override fun onError(error: Int) {
                state = if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) State.Denied else State.Idle
            }
            override fun onEndOfSpeech() {}
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-GB")
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        runCatching { r.startListening(intent); state = State.Listening }.onFailure { state = State.Unavailable }
    }

    /** Stops listening; the text so far stays in [text]. */
    fun stop() {
        if (!isListening) return
        runCatching { recognizer?.stopListening() }
        state = State.Idle
    }

    fun release() {
        runCatching { recognizer?.destroy() }
        recognizer = null
        if (isListening) state = State.Idle
    }

    private fun best(b: Bundle?) = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.takeIf { it.isNotBlank() }
}
