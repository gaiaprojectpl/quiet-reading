package app.quietreading.feature.companion

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import app.quietreading.data.Book
import app.quietreading.data.Keys
import app.quietreading.data.ReadingStatus
import app.quietreading.feature.stats.ReadingStats
import app.quietreading.feature.stats.oneDecimal
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Flow 12 · Reading companion. Settings keys (same names as iOS, Astrid & privacy). */
object CompanionKeys {
    val enabled = Keys.companionEnabled                                    // set by the consent screen
    val includeNotes = booleanPreferencesKey("companionIncludeNotes")
    val nudge = booleanPreferencesKey("companionNudge")                    // one Home card near the end of a book
    val historyDays = intPreferencesKey("companionHistoryDays")            // 30 (default), 7, 0 = don't keep
    val notForMe = stringPreferencesKey("companionNotForMe")               // titles turned down, joined with "\n"
    val nudgeDismissed = stringPreferencesKey("companionNudgeDismissed")
}

/** A real book suggested inside an answer (Chat book card). Always from the catalogue. */
data class CompanionPick(
    val id: String,
    val title: String,
    val author: String,
    val pageCount: Int? = null,
    val isbn: String? = null,
    val coverUrl: String? = null,
    val reason: String = "",
    val state: State = State.Open,
) {
    enum class State { Open, Added, NotForMe }

    fun json(): JSONObject = JSONObject().put("id", id).put("title", title).put("author", author)
        .put("pageCount", pageCount ?: JSONObject.NULL).put("isbn", isbn ?: JSONObject.NULL)
        .put("coverUrl", coverUrl ?: JSONObject.NULL).put("reason", reason).put("state", state.name)

    companion object {
        fun from(o: JSONObject) = CompanionPick(
            o.optString("id"), o.optString("title"), o.optString("author"),
            o.optInt("pageCount", 0).takeIf { it > 0 }, o.optString("isbn").takeIf { it.isNotEmpty() && it != "null" },
            o.optString("coverUrl").takeIf { it.isNotEmpty() && it != "null" }, o.optString("reason"),
            runCatching { State.valueOf(o.optString("state")) }.getOrDefault(State.Open),
        )
    }
}

/** One turn in the conversation. */
data class CompanionMessage(
    val role: Role,
    val text: String,
    val picks: List<CompanionPick> = emptyList(),
    val followUps: List<String> = emptyList(),
    val showGoal: Boolean = false,
    val status: Status = Status.Done,
    val date: Long = System.currentTimeMillis(),
    /** 1 helpful, -1 not helpful. */
    val feedback: Int = 0,
    val id: String = UUID.randomUUID().toString(),
) {
    enum class Role { Me, Companion }
    enum class Status { Done, Streaming, Failed }

    fun json(): JSONObject = JSONObject().put("id", id).put("role", role.name).put("text", text)
        .put("picks", JSONArray(picks.map { it.json() })).put("followUps", JSONArray(followUps))
        .put("showGoal", showGoal).put("status", status.name).put("date", date).put("feedback", feedback)

    companion object {
        fun from(o: JSONObject): CompanionMessage? = runCatching {
            val picks = o.optJSONArray("picks")
            val follow = o.optJSONArray("followUps")
            CompanionMessage(
                role = Role.valueOf(o.getString("role")), text = o.optString("text"),
                picks = picks?.let { a -> (0 until a.length()).map { CompanionPick.from(a.getJSONObject(it)) } }.orEmpty(),
                followUps = follow?.let { a -> (0 until a.length()).map { a.getString(it) } }.orEmpty(),
                showGoal = o.optBoolean("showGoal"), status = Status.valueOf(o.optString("status", "Done")),
                date = o.optLong("date"), feedback = o.optInt("feedback"), id = o.optString("id"),
            )
        }.getOrNull()
    }
}

/**
 * What the companion knows about the reader. Titles, authors, ratings, moods and progress only:
 * never the name, email, photo or location. Notes only when the reader turns them on.
 */
class CompanionContext(books: List<Book>, val goal: Int, includeNotes: Boolean, val notForMe: List<String>, val liked: List<String> = emptyList()) {
    data class Line(val title: String, val author: String, val stars: Double?, val moods: List<String>, val pages: Int?)

    private fun line(b: Book) = Line(b.title, b.author, b.stars ?: b.entity.rating?.toDouble(), b.moods, b.pageCount)

    val finished: List<Line>
    val reading: List<Line>
    val wantToRead: List<Line>
    val notes: List<String>
    val finishedThisYear: Int
    val year: Int
    val perMonth: Double
    val onPaceFor: Int
    val currentTitle: String?
    val pagesLeftInCurrent: Int?
    val libraryKeys: Set<String>

    init {
        val stats = ReadingStats(books)
        finished = stats.finished.sortedWith(compareByDescending<Book> { it.stars ?: 0.0 }.thenByDescending { it.dateFinished ?: 0 }).take(25).map(::line)
        val readingBooks = books.filter { it.status == ReadingStatus.Reading }.sortedByDescending { it.lastUpdated }
        reading = readingBooks.map(::line)
        wantToRead = books.filter { it.status == ReadingStatus.ToRead }.take(10).map(::line)
        notes = if (includeNotes) books.flatMap { b -> b.sessions.mapNotNull { it.note } }.takeLast(10).map { it.take(160) } else emptyList()
        val g = stats.goal(goal, stats.currentYear)
        finishedThisYear = g.done
        year = stats.currentYear
        perMonth = g.perMonth
        onPaceFor = g.onPaceFor
        currentTitle = readingBooks.firstOrNull()?.title
        pagesLeftInCurrent = readingBooks.firstOrNull()?.let { b -> b.pageCount?.let { maxOf(0, it - b.currentPage) } }
        libraryKeys = books.map { key(it.title) }.toSet()
    }

    companion object {
        fun key(title: String) = title.lowercase().filter { it.isLetterOrDigit() }
    }
}

/**
 * The model returns a small Markdown subset; anything outside it is removed before display
 * (headings, emoji, links, code, tables, exclamation marks, internal fields).
 */
object CompanionText {
    private val words = mapOf(1 to "one", 2 to "two", 3 to "three", 4 to "four", 5 to "five")

    /** Books can be dropped when the catalogue can't confirm them, so "two/three books" must match the cards shown. */
    fun matchCount(text: String, picks: Int): String {
        if (picks <= 0) return text
        val right = words[picks] ?: return text
        var out = text
        for ((n, w) in words) {
            if (n == picks) continue
            out = out.replace("**$w ", "**$right ").replace("**${w.cap()} ", "**${right.cap()} ")
            out = Regex("\\b$w ").replaceFirst(out, "$right ")
            out = Regex("\\b${w.cap()} ").replaceFirst(out, "${right.cap()} ")
        }
        if (picks == 1) {
            for ((a, b) in listOf("books" to "book", "tales" to "tale", "stories" to "story", "standalones" to "standalone", "reads" to "read", "Both" to "It", "both" to "it")) {
                out = out.replace(" $a ", " $b ").replace(" $a**", " $b**")
                if (out.startsWith("$a ")) out = b + out.removePrefix(a)
            }
        }
        return out
    }

    private fun String.cap() = replaceFirstChar { it.uppercase() }

    /** Bold is for short key facts only: unbold anything longer than 5 words. */
    fun unboldLong(line: String): String = Regex("\\*\\*([^*]+)\\*\\*").replace(line) { m ->
        val inner = m.groupValues[1]
        if (inner.trim().split(Regex("\\s+")).size > 5) inner else m.value
    }

    private fun isEmoji(cp: Int) = (cp in 0x1F000..0x1FAFF) || (cp in 0x2600..0x27BF) || (cp in 0x2B00..0x2BFF) || cp == 0xFE0F || cp == 0x200D

    /** Marks where the visible answer ends in the model's output (reason lines, follow-ups). */
    private val internal = Regex("^(c\\d+\\s*[:|\\-]|picks|followups|follow-ups|follow ups|follow:|showgoal|reasons?:)", RegexOption.IGNORE_CASE)

    fun sanitize(s: String): String {
        val lines = mutableListOf<String>()
        for (raw in s.split("\n")) {
            var l = raw
            if (l.trim().startsWith("#")) l = l.replace("#", "").trim()
            if (l.count { it == '|' } >= 2) continue
            if (l.trim().startsWith("```")) continue
            if (internal.containsMatchIn(l.trim())) break
            l = l.replace(Regex("^\\s*(text|answer)\\s*:\\s*", RegexOption.IGNORE_CASE), "")
            l = l.replace(Regex("\\s*\\[?\\bc\\d+\\b]?"), "")
            l = l.replace(Regex("https?://\\S+"), "")
            l = l.replace("!", ".")
            l = buildString { l.codePoints().forEach { if (!isEmoji(it)) appendCodePoint(it) } }
            l = unboldLong(l).replace("  ", " ")
            lines += l
        }
        return lines.joinToString("\n").replace("\n\n\n", "\n\n").trim()
    }
}

/** Answers that don't need the model (numbers always come from the app), and calm "not available" lines. */
object CompanionFallback {
    fun answer(q: String, c: CompanionContext): CompanionMessage? {
        val lower = q.lowercase().replace('’', '\'')
        val asksNumbers = listOf("goal", "my year", "this year", "how is my reading", "how's my reading", "how many books").any { lower.contains(it) }
        if (!asksNumbers || lower.contains("plan") || lower.contains("next book")) return null
        return CompanionMessage(CompanionMessage.Role.Companion, goalText(c), followUps = listOf("Open my stats", "Find my next book"), showGoal = true)
    }

    fun goalText(c: CompanionContext): String {
        val perMonth = c.perMonth.oneDecimal()
        if (c.goal > 0) {
            if (c.finishedThisYear >= c.goal) return "You’ve finished **${c.finishedThisYear} of your ${c.goal} books** this year. Your goal is reached. What a lovely year of stories."
            return "You’ve finished **${c.finishedThisYear} of your ${c.goal} books** so far this year, about **$perMonth a month**. At this gentle pace you’d finish around ${c.onPaceFor} this year. Take your time."
        }
        if (c.finishedThisYear == 0) return "Some months are for living, not reading. Your books will wait for you, and I’ll be here whenever you’re ready."
        return "You’ve finished **${c.finishedThisYear} books** so far this year, about **$perMonth a month**. What a lovely year of stories."
    }

    fun unavailable(a: Availability): CompanionMessage {
        val text = when (a) {
            Availability.Downloadable, Availability.Downloading ->
                "I’m still getting ready on your phone. Once the download has finished I can talk about books with you. Your goal and reading numbers work already."
            Availability.Unavailable ->
                "On this phone I can tell you how your reading year is going. Talking about books needs a phone with Gemini Nano, I’m sorry to say. Everything else in Quiet Reading works as usual."
            Availability.Checking, Availability.Available -> "I’m still getting ready. Would you ask me again in a moment?"
        }
        return CompanionMessage(CompanionMessage.Role.Companion, text, followUps = listOf("How is my reading goal going?"))
    }
}

/** Whether the on-device model (Gemini Nano via ML Kit GenAI) can answer on this phone. */
enum class Availability { Checking, Available, Downloadable, Downloading, Unavailable }
