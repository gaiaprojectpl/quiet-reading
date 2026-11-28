package app.quietreading.feature.companion

import android.util.Log
import app.quietreading.data.BookCandidate
import app.quietreading.data.BookSearch
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.SystemInstruction
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import org.json.JSONObject

/** One streamed step of an answer. Picks, follow-ups and the goal card arrive with the final step. */
data class CompanionPartial(
    val text: String,
    val picks: List<CompanionPick> = emptyList(),
    val followUps: List<String> = emptyList(),
    val showGoal: Boolean = false,
    val isFinal: Boolean = false,
)

class CompanionError(message: String) : Exception(message)

/**
 * Astrid on Android: Gemini Nano on the phone through ML Kit GenAI (Prompt API).
 * Same pipeline as iOS: plan → verify every named book in the catalogue → answer about at most 3 real books.
 * Cloud answers come with the backend; no key ever ships in the app.
 */
class OnDeviceCompanion {
    private val model: GenerativeModel by lazy { Generation.getClient() }
    private var systemPrompts: Boolean? = null

    suspend fun availability(): Availability = runCatching {
        when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> Availability.Available
            FeatureStatus.DOWNLOADABLE -> Availability.Downloadable
            FeatureStatus.DOWNLOADING -> Availability.Downloading
            else -> Availability.Unavailable
        }
    }.getOrElse { Log.i("Astrid", "checkStatus failed: $it"); Availability.Unavailable }

    /** One-time model download (sizes in bytes). */
    fun download(): Flow<DownloadStatus> = model.download()

    private suspend fun request(system: String, prompt: String, maxTokens: Int, temperature: Float) = run {
        val sys = systemPrompts ?: runCatching { model.isSystemPromptAvailable() }.getOrDefault(false).also { systemPrompts = it }
        if (sys) generateContentRequest(SystemInstruction(system), TextPart(prompt)) { maxOutputTokens = maxTokens; this.temperature = temperature }
        else generateContentRequest(TextPart("$system\n\n$prompt")) { maxOutputTokens = maxTokens; this.temperature = temperature }
    }

    fun answer(question: String, context: CompanionContext, history: List<CompanionMessage>): Flow<CompanionPartial> = flow {
        try {
            // Step 1 · plan: does the reader want books, and which real, well-known books fit?
            val plan = plan(question, context)
            Log.i("Astrid", "plan wants=${plan.first} titles=${plan.second}")

            // Step 2 · verify every title against the catalogue (no invented books).
            var catalogue = ""
            var found: List<BookCandidate> = emptyList()
            if (plan.first) {
                val exclude = context.libraryKeys + context.notForMe.map(CompanionContext::key)
                val hits = mutableListOf<BookCandidate>()
                for (t in plan.second.take(5)) {
                    val hit = verify(t) ?: continue
                    val k = CompanionContext.key(hit.title)
                    if (k !in exclude && hits.none { CompanionContext.key(it.title) == k }) hits += hit
                }
                if (hits.isEmpty()) {
                    // Nothing could be confirmed as a real book: say so honestly instead of letting the model guess.
                    val upNext = context.wantToRead.firstOrNull()?.title
                    val text = if (upNext != null) "I couldn’t find a good match in the library just now. While I keep looking, *$upNext* is waiting on your Up next. What did you love most in your last good read?"
                        else "I couldn’t find a good match in the library just now. What did you love most in your last good read? It helps me look in the right place."
                    emit(CompanionPartial(text, followUps = listOf("Something cosy", "Something short"), isFinal = true))
                    return@flow
                }
                found = hits.take(3)   // at most 3 cards per answer
                catalogue = "\n\nReal books you may suggest. There ${if (found.size == 1) "is 1 book" else "are ${found.size} books"}: talk about ${if (found.size == 1) "one book" else "${words(found.size)} books"}, never a different number, never other books:\n" +
                    found.mapIndexed { i, c -> "c${i + 1}: ${c.title} by ${firstAuthor(c.author)}" + (c.pageCount?.let { ", $it pages" } ?: "") }.joinToString("\n") +
                    "\n\nAfter the answer, write one line per book: c1: a reason of at most 120 characters tied to a book the reader finished or rated."
            }

            // Step 3 · answer, streamed.
            val recent = history.takeLast(4).joinToString("\n") { (if (it.role == CompanionMessage.Role.Me) "Reader: " else "Astrid: ") + it.text.take(300) }
            val prompt = buildString {
                if (recent.isNotBlank()) append("Conversation so far:\n$recent\n\n")
                append("Reader: $question")
                append(catalogue)
                append("\n\nLast, write one line starting with FOLLOW: and up to 3 short replies the reader might tap next, 1 to 4 words each, separated by |.")
            }
            var full = ""
            model.generateContentStream(request(instructions(context), prompt, 450, 0.4f)).collect { chunk ->
                val piece = chunk.candidates.firstOrNull()?.text.orEmpty()
                full = if (piece.startsWith(full)) piece else full + piece
                emit(CompanionPartial(CompanionText.sanitize(full)))
            }
            emit(finalPartial(full, found))
        } catch (e: GenAiException) {
            Log.w("Astrid", "GenAI error ${e.errorCode}", e)
            throw friendly(e)?.let(::CompanionError) ?: e
        }
    }

    private fun finalPartial(full: String, found: List<BookCandidate>): CompanionPartial {
        val reasons = mutableMapOf<Int, String>()
        var follow = emptyList<String>()
        for (line in full.lines()) {
            val t = line.trim().trimStart('-', '*', ' ')
            Regex("^c(\\d+)\\s*[:|\\-]\\s*(.+)$", RegexOption.IGNORE_CASE).find(t)?.let { m ->
                reasons[m.groupValues[1].toInt()] = cleanReason(m.groupValues[2])
            }
            if (t.startsWith("FOLLOW", ignoreCase = true)) {
                follow = t.substringAfter(":").split("|", ";").map { it.trim().trim('"', '.', '*') }.filter { it.isNotEmpty() && it.length <= 32 }.take(3)
            }
        }
        val picks = found.mapIndexed { i, c ->
            CompanionPick(c.id, c.title, cleanAuthors(c.author), c.pageCount, c.isbn, c.coverUrl, reasons[i + 1].orEmpty())
        }
        val text = CompanionText.matchCount(CompanionText.sanitize(full), picks.size)
            .ifEmpty { "Here’s what I found. I hope you enjoy them." }
        return CompanionPartial(text, picks, follow, isFinal = true)
    }

    /** Planner: JSON with wantsBooks and 3–5 "Title by Author". Lenient parsing; small model. */
    private suspend fun plan(question: String, c: CompanionContext): Pair<Boolean, List<String>> {
        val profile = c.finished.take(8).joinToString("; ") { l -> "${l.title} by ${l.author}" + if (l.moods.isEmpty()) "" else " (${l.moods.take(2).joinToString(", ")})" }
        val system = "You turn a reader's message into book ideas. Reply with JSON only, like {\"wantsBooks\": true, \"titles\": [\"Title by Author\"]}. " +
            "wantsBooks is true if the reader wants book suggestions or ideas for what to read. titles: 3 to 5 real, published, well-known books that fit, never books from the reader's own lists." +
            (if (profile.isNotEmpty()) " Reader's favourite books: $profile" else "")
        val text = model.generateContent(request(system, question, 200, 0.2f)).candidates.firstOrNull()?.text.orEmpty()
        val json = text.substringAfter("{", "").substringBeforeLast("}", "")
        val obj = runCatching { JSONObject("{$json}") }.getOrNull()
        if (obj != null) {
            val titles = obj.optJSONArray("titles")?.let { a -> (0 until a.length()).map { a.optString(it) } }.orEmpty().filter { it.isNotBlank() }
            return obj.optBoolean("wantsBooks", titles.isNotEmpty()) to titles
        }
        val lower = question.lowercase()
        val wants = listOf("book", "read next", "recommend", "suggest", "something").any { lower.contains(it) }
        return wants to emptyList()
    }

    private fun instructions(c: CompanionContext): String {
        fun fmt(l: CompanionContext.Line) = buildString {
            append("${l.title} by ${l.author}")
            l.stars?.let { append(", rated ${if (it % 1.0 == 0.0) it.toInt() else it} of 5") }
            if (l.moods.isNotEmpty()) append(", felt ${l.moods.take(2).joinToString(" and ").lowercase()}")
        }
        return buildString {
            append("""
                You are Astrid, the reading companion in the Quiet Reading app. You are an AI.
                Persona: a kind, patient, well-read grandmother of stories who works like a librarian: ask what they loved, offer a few good matches with one reason each, and let them choose.
                Values: every reader her book; there is no wrong way to read; never judge, grade or label the reader or their taste.
                Voice: warm, calm, polite, British spelling. Answer first. 1 to 3 short sentences per paragraph, at most 90 words. When suggesting books, do not list them: the cards show them; say how many there are and what they share. Write every book title as *Title*. Use **bold** only for up to 3 short facts. No emoji, no exclamation marks, no headings, no tables, no links, no pet names. Words you avoid: only, behind, should, must, failed, streak, hurry, guilty pleasure, actually, obviously.
                Rules: only recommend books from the 'Real books you may suggest' list in the message. Never invent titles, quotes or facts. Never claim to be human. No spoilers unless asked. Stay on books and reading. If the reader shares something distressing, respond kindly and suggest reaching out to someone they trust or a support line.
                Use only the numbers below; never guess numbers.
            """.trimIndent())
            append("\nReader's year ${c.year}: finished ${c.finishedThisYear} books.")
            if (c.goal > 0) append(" Goal: ${c.goal} books, on pace for ${c.onPaceFor}.")
            c.currentTitle?.let { append("\nReading now: $it" + (c.pagesLeftInCurrent?.let { p -> ", $p pages left" } ?: "") + ".") }
            if (c.finished.isNotEmpty()) append("\nFinished, favourites first: " + c.finished.take(10).joinToString("; ", transform = ::fmt) + ".")
            if (c.wantToRead.isNotEmpty()) append("\nAlready on their Up next list: " + c.wantToRead.take(6).joinToString("; ") { it.title } + ".")
            if (c.notForMe.isNotEmpty()) append("\nThey said not for me to: " + c.notForMe.takeLast(10).joinToString("; ") + ".")
            if (c.liked.isNotEmpty()) append("\nSuggestions they found helpful: " + c.liked.takeLast(6).joinToString("; ") + ".")
            if (c.notes.isNotEmpty()) append("\nTheir recent notes: " + c.notes.joinToString(" / "))
        }
    }

    companion object {
        private fun words(n: Int) = mapOf(1 to "one", 2 to "two", 3 to "three")[n] ?: n.toString()
        private fun firstAuthor(a: String) = a.split(", ").firstOrNull().orEmpty()

        /** Catalogues sometimes repeat the author or list illustrators and translators. */
        fun cleanAuthors(a: String): String {
            val names = mutableListOf<String>()
            for (n in a.split(", ")) {
                val low = n.lowercase()
                if (listOf("illustrat", "cover art", "editor", "translat").any { low.contains(it) }) continue
                if (n.isNotBlank() && n !in names) names += n
            }
            return names.joinToString(", ")
        }

        fun cleanReason(r: String): String {
            var s = r.replace(Regex("\\s*\\[[^]]*]"), "").replace("*", "").replace("!", ".").trim().trim('"')
            s = s.replaceFirstChar { it.uppercase() }
            return s.take(140)
        }

        /**
         * Checks a book the model named ("Title by Author") against the catalogue.
         * Same title and author, and never a study guide, summary or workbook. Unverifiable → null (dropped).
         */
        suspend fun verify(named: String): BookCandidate? {
            val parts = named.split(" by ")
            val title = CompanionContext.key(parts[0])
            val author = if (parts.size > 1) CompanionContext.key(parts[1].trim().split(" ").last()) else ""
            if (title.length < 3) return null
            val notBooks = listOf("guide", "summary", "study", "notes", "workbook", "analysis", "sparknotes", "teacher", "companion to", "collection set")
            // Search "Title Author" (not "Title by Author": catalogues then return study guides first).
            return BookSearch.search(parts.joinToString(" ")).firstOrNull { c ->
                val k = CompanionContext.key(c.title)
                val lower = c.title.lowercase()
                if (notBooks.any { lower.contains(it) } || c.author.isEmpty()) return@firstOrNull false
                if (!(k == title || (k.startsWith(title) && k.length - title.length <= 40))) return@firstOrNull false
                author.isEmpty() || CompanionContext.key(c.author).contains(author) || author.contains(CompanionContext.key(c.author.split(",").first()))
            }
        }

        /** Calm words for every error; never an error code. Null = "Something went wrong" with Try again. */
        fun friendly(e: GenAiException): String? = when (e.errorCode) {
            GenAiException.ErrorCode.BUSY, GenAiException.ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED,
            GenAiException.ErrorCode.BACKGROUND_USE_BLOCKED -> "I need a short pause. Shall we try again in a minute?"
            GenAiException.ErrorCode.REQUEST_TOO_LARGE, GenAiException.ErrorCode.MAX_TURNS_EXCEEDED ->
                "Our chat got long, so I’ve turned to a fresh page. Would you ask me that once more?"
            GenAiException.ErrorCode.NOT_ENOUGH_DISK_SPACE -> "Your phone is short of space, so I can’t get ready just now. Your books are safe."
            GenAiException.ErrorCode.NEEDS_SYSTEM_UPDATE -> "I need a system update on this phone before we can chat about books. Your goal and reading numbers work already."
            else -> null
        }
    }
}
