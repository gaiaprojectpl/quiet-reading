package app.quietreading.feature.companion

import android.content.Context
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import app.quietreading.QuietReadingApplication
import app.quietreading.data.Book
import app.quietreading.data.Prefs
import com.google.mlkit.genai.common.DownloadStatus
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.File

/**
 * The conversation, its state and Astrid's settings. Lives for the app process;
 * the chat text is kept on this phone for the chosen number of days (30 by default).
 */
class CompanionStore private constructor(context: Context) {
    enum class Phase { Idle, Thinking, Answering }

    private val prefs: Prefs = (context.applicationContext as QuietReadingApplication).env.prefs
    private val file = File(context.filesDir, "companion-chat.json")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val engine = OnDeviceCompanion()
    private var task: Job? = null

    val messages = mutableStateListOf<CompanionMessage>()
    var phase by mutableStateOf(Phase.Idle)
        private set
    var availability by mutableStateOf(Availability.Checking)
        private set
    /** Bytes downloaded / to download while the model is fetched (null = not downloading). */
    var download by mutableStateOf<Pair<Long, Long>?>(null)
        private set
    /** Held as state so "Turn on Astrid" switches to the chat straight away. */
    var isEnabled by mutableStateOf(false)
        private set
    var includeNotes by mutableStateOf(false)
        private set
    var historyDays by mutableStateOf(30)
        private set
    var nudge by mutableStateOf(false)
        private set
    /** A question to ask as soon as the chat opens (Home nudge, starters from elsewhere). */
    var pendingPrompt by mutableStateOf<String?>(null)
    var loaded by mutableStateOf(false)
        private set
    private var notForMe: List<String> = emptyList()

    init {
        scope.launch {
            isEnabled = prefs.get(CompanionKeys.enabled, false)
            includeNotes = prefs.get(CompanionKeys.includeNotes, false)
            historyDays = prefs.get(CompanionKeys.historyDays, 30)
            nudge = prefs.get(CompanionKeys.nudge, false)
            notForMe = prefs.get(CompanionKeys.notForMe, "").split("\n").filter { it.isNotBlank() }
            load()
            loaded = true
            refreshAvailability()
        }
    }

    fun changeEnabled(on: Boolean) {
        isEnabled = on
        scope.launch { prefs.set(CompanionKeys.enabled, on) }
        if (!on) deleteHistory()
    }

    fun changeIncludeNotes(on: Boolean) { includeNotes = on; scope.launch { prefs.set(CompanionKeys.includeNotes, on) } }
    fun changeNudge(on: Boolean) { nudge = on; scope.launch { prefs.set(CompanionKeys.nudge, on) } }
    fun changeHistoryDays(days: Int) {
        historyDays = days
        scope.launch { prefs.set(CompanionKeys.historyDays, days) }
        if (days == 0) deleteHistory() else save()
    }

    fun refreshAvailability() {
        scope.launch { if (download == null) availability = engine.availability() }
    }

    /** One-time Gemini Nano download, with progress. */
    fun startDownload() {
        if (download != null) return
        download = 0L to 0L
        availability = Availability.Downloading
        scope.launch {
            var total = 0L
            runCatching {
                engine.download().collect { s ->
                    when (s) {
                        is DownloadStatus.DownloadStarted -> { total = s.bytesToDownload; download = 0L to total }
                        is DownloadStatus.DownloadProgress -> download = s.totalBytesDownloaded to total
                        is DownloadStatus.DownloadCompleted -> { download = null; availability = Availability.Available }
                        is DownloadStatus.DownloadFailed -> { download = null; availability = Availability.Downloadable }
                    }
                }
            }.onFailure { Log.w("Astrid", "download failed", it); download = null; availability = engine.availability() }
            if (download != null) { download = null; availability = engine.availability() }
        }
    }

    // Asking

    fun send(text: String, books: List<Book>, goal: Int) {
        val question = text.trim()
        if (question.isEmpty() || phase != Phase.Idle) return
        messages += CompanionMessage(CompanionMessage.Role.Me, question)
        run(question, books, goal)
    }

    /** "Not sent · Tap to try again". */
    fun retry(message: CompanionMessage, books: List<Book>, goal: Int) {
        val i = messages.indexOfFirst { it.id == message.id }
        if (i < 0 || phase != Phase.Idle) return
        messages[i] = messages[i].copy(status = CompanionMessage.Status.Done)
        if (i + 1 < messages.size && messages[i + 1].status == CompanionMessage.Status.Failed) messages.removeAt(i + 1)
        run(message.text, books, goal)
    }

    fun stop() {
        task?.cancel()
        task = null
        val last = messages.lastIndex
        if (last >= 0 && messages[last].status == CompanionMessage.Status.Streaming) messages[last] = messages[last].copy(status = CompanionMessage.Status.Done)
        phase = Phase.Idle
    }

    private fun run(question: String, books: List<Book>, goal: Int) {
        phase = Phase.Thinking
        // 👍 / 👎 shape the next answers.
        val liked = messages.filter { it.feedback == 1 }.flatMap { m -> m.picks.map { it.title } }
        val disliked = messages.filter { it.feedback == -1 }.flatMap { m -> m.picks.map { it.title } }
        val context = CompanionContext(books, goal, includeNotes, notForMe + disliked, liked)
        val history = messages.dropLast(1).takeLast(6).toList()
        task = scope.launch {
            try {
                // Numbers about the goal and the year always come from the app, never the model. Works without AI too.
                CompanionFallback.answer(question, context)?.let {
                    delay(600)
                    messages += it
                    return@launch
                }
                if (availability != Availability.Available) {
                    availability = engine.availability()
                    if (availability != Availability.Available) {
                        delay(700)
                        messages += CompanionFallback.unavailable(availability)
                        return@launch
                    }
                }
                var reply = CompanionMessage(CompanionMessage.Role.Companion, "", status = CompanionMessage.Status.Streaming)
                withContext(Dispatchers.Default) {
                    engine.answer(question, context, history).collect { partial ->
                        withContext(Dispatchers.Main) { show(partial, reply).let { reply = it } }
                    }
                }
                if (messages.none { it.id == reply.id }) {
                    messages += CompanionMessage(CompanionMessage.Role.Companion, "I couldn’t find a good answer to that. Would you ask me another way?")
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: CompanionError) {
                messages += CompanionMessage(CompanionMessage.Role.Companion, e.message.orEmpty())
            } catch (e: Exception) {
                Log.e("Astrid", "Companion failed", e)
                // Flow 12 › Something went wrong: the question stays, marked "Not sent".
                val last = messages.indexOfLast { it.role == CompanionMessage.Role.Me }
                if (last >= 0) {
                    messages[last] = messages[last].copy(status = CompanionMessage.Status.Failed)
                    messages += CompanionMessage(CompanionMessage.Role.Companion, "Something went wrong on my side. Your message is saved; shall I try again?", status = CompanionMessage.Status.Failed)
                }
            } finally {
                phase = Phase.Idle
                save()
            }
        }
    }

    /** Streams the answer in (all at once with Reduce Motion handled by the view's fade). */
    private fun show(p: CompanionPartial, reply: CompanionMessage): CompanionMessage {
        var r = reply.copy(text = p.text)
        val i = messages.indexOfFirst { it.id == r.id }
        if (p.isFinal) {
            r = r.copy(text = p.text, picks = p.picks, followUps = p.followUps, showGoal = p.showGoal, status = CompanionMessage.Status.Done)
        }
        if (i < 0) {
            if (r.text.isEmpty() && !p.isFinal) return r
            phase = Phase.Answering
            messages += r
        } else {
            messages[i] = r
        }
        return r
    }

    // Picks & feedback

    fun setPick(pick: CompanionPick, message: CompanionMessage, state: CompanionPick.State) {
        val m = messages.indexOfFirst { it.id == message.id }
        if (m < 0) return
        val current = messages[m]
        val othersDeclined = current.picks.any { it.state == CompanionPick.State.NotForMe && it.id != pick.id }
        messages[m] = current.copy(picks = current.picks.map { if (it.id == pick.id) it.copy(state = state) else it })
        if (state == CompanionPick.State.NotForMe) {
            notForMe = (notForMe + pick.title).takeLast(50)
            scope.launch { prefs.set(CompanionKeys.notForMe, notForMe.joinToString("\n")) }
            // Astrid · key line "Not for me" (only once per answer).
            if (!othersDeclined) messages.add(m + 1, CompanionMessage(CompanionMessage.Role.Companion, "Thank you for telling me. I’ll remember that and find something different."))
        }
        save()
    }

    fun rate(message: CompanionMessage, value: Int) {
        val i = messages.indexOfFirst { it.id == message.id }
        if (i < 0) return
        messages[i] = messages[i].copy(feedback = if (messages[i].feedback == value) 0 else value)
        save()
    }

    // History (kept on this phone only)

    fun save() {
        if (historyDays <= 0) return
        val kept = messages.filter { it.status != CompanionMessage.Status.Streaming }.map { it.json() }
        scope.launch(Dispatchers.IO) { runCatching { file.writeText(JSONArray(kept).toString()) } }
    }

    private suspend fun load() {
        if (historyDays <= 0) return
        val saved = withContext(Dispatchers.IO) {
            runCatching { JSONArray(file.readText()) }.getOrNull()?.let { a -> (0 until a.length()).mapNotNull { CompanionMessage.from(a.getJSONObject(it)) } }
        } ?: return
        val cutoff = System.currentTimeMillis() - historyDays * 86_400_000L
        messages.clear()
        messages += saved.filter { it.date >= cutoff }
    }

    fun deleteHistory() {
        stop()
        messages.clear()
        scope.launch(Dispatchers.IO) { file.delete() }
    }

    companion object {
        @Volatile private var instance: CompanionStore? = null
        fun get(context: Context): CompanionStore = instance ?: synchronized(this) {
            instance ?: CompanionStore(context.applicationContext).also { instance = it }
        }
    }
}

@Composable
fun rememberCompanion(): CompanionStore {
    val context = LocalContext.current
    return remember { CompanionStore.get(context) }
}
