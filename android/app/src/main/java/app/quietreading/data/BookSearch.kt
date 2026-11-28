package app.quietreading.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.UUID

/** One edition found online, shown in "Is this the book?" and search results. */
data class BookCandidate(
    val id: String,
    val title: String,
    val author: String,
    val pageCount: Int? = null,
    val isbn: String? = null,
    val coverUrl: String? = null,
    /** "English edition", "Polish edition"… */
    val detail: String? = null,
)

/**
 * Finds books online: Google Books first (editions, languages, covers), Open Library as a fallback.
 * Runs without an API key (fine for personal use; a key or a small server comes before release).
 */
object BookSearch {
    suspend fun search(query: String): List<BookCandidate> {
        val q = query.trim()
        if (q.isEmpty()) return emptyList()
        var results = googleBooks("q=${encode(q)}")
        if (results.isEmpty()) results = openLibrary("q=${encode(q)}")
        return rank(results, q)
    }

    suspend fun lookup(isbn: String): List<BookCandidate> {
        val google = googleBooks("q=isbn:$isbn")
        return google.ifEmpty { openLibrary("isbn=$isbn") }
    }

    /** A cover for an ISBN: Open Library first, then Google Books, then [fallbackUrl]. */
    suspend fun coverBytes(isbn: String?, fallbackUrl: String? = null): ByteArray? {
        if (isbn != null) {
            download("https://covers.openlibrary.org/b/isbn/$isbn-M.jpg?default=false")?.let { return it }
            googleBooks("q=isbn:$isbn").firstOrNull()?.coverUrl?.let { url -> download(url)?.let { return it } }
        }
        return fallbackUrl?.let { download(it) }
    }

    private fun words(s: String) = s.lowercase().split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }.toSet()

    /** Books whose title and author share the most words with the query come first (stable otherwise). */
    private fun rank(results: List<BookCandidate>, query: String): List<BookCandidate> {
        val q = words(query).filter { it.length > 1 }.toSet()
        if (q.isEmpty()) return results
        fun score(c: BookCandidate): Double {
            val t = words(c.title)
            val a = words(c.author)
            val english = if (c.detail == null || c.detail == "English edition") 1.5 else 0.0  // the app is English
            return (q intersect t).size * 2.0 + (q intersect a).size - (t - q).size + english
        }
        return results.withIndex().sortedWith(compareByDescending<IndexedValue<BookCandidate>> { score(it.value) }.thenBy { it.index }).map { it.value }
    }

    private suspend fun googleBooks(query: String): List<BookCandidate> {
        val fields = "items(id,volumeInfo(title,subtitle,authors,pageCount,language,printType,industryIdentifiers,imageLinks/thumbnail))"
        val json = get("https://www.googleapis.com/books/v1/volumes?$query&maxResults=12&printType=books&fields=${encode(fields)}") ?: return emptyList()
        val items = runCatching { JSONObject(json).optJSONArray("items") }.getOrNull() ?: return emptyList()
        return items.objects().mapNotNull { item ->
            val info = item.optJSONObject("volumeInfo") ?: return@mapNotNull null
            val title = info.optString("title").ifEmpty { return@mapNotNull null }
            val ids = info.optJSONArray("industryIdentifiers")?.objects().orEmpty()
            val isbn = ids.firstOrNull { it.optString("type") == "ISBN_13" }?.optString("identifier")
                ?: ids.firstOrNull { it.optString("type") == "ISBN_10" }?.optString("identifier")
            val thumb = info.optJSONObject("imageLinks")?.optString("thumbnail")?.takeIf { it.isNotEmpty() }
                ?.replace("http://", "https://")?.replace("&edge=curl", "")
            BookCandidate(
                id = item.optString("id").ifEmpty { UUID.randomUUID().toString() },
                title = title,
                author = info.optJSONArray("authors")?.strings().orEmpty().joinToString(", "),
                pageCount = info.optInt("pageCount", 0).takeIf { it > 0 },
                isbn = isbn,
                coverUrl = thumb,
                detail = info.optString("language").takeIf { it.isNotEmpty() }?.let(::editionName),
            )
        }
    }

    private suspend fun openLibrary(query: String): List<BookCandidate> {
        val json = get("https://openlibrary.org/search.json?$query&limit=12&fields=key,title,author_name,isbn,number_of_pages_median,cover_i,language") ?: return emptyList()
        val docs = runCatching { JSONObject(json).optJSONArray("docs") }.getOrNull() ?: return emptyList()
        return docs.objects().mapNotNull { doc ->
            val title = doc.optString("title").ifEmpty { return@mapNotNull null }
            val isbns = doc.optJSONArray("isbn")?.strings().orEmpty()
            val cover = doc.optInt("cover_i", 0).takeIf { it > 0 }?.let { "https://covers.openlibrary.org/b/id/$it-M.jpg" }
            BookCandidate(
                id = doc.optString("key").ifEmpty { UUID.randomUUID().toString() },
                title = title,
                author = doc.optJSONArray("author_name")?.strings().orEmpty().take(2).joinToString(", "),
                pageCount = doc.optInt("number_of_pages_median", 0).takeIf { it > 0 },
                isbn = isbns.firstOrNull { it.length == 13 } ?: isbns.firstOrNull(),
                coverUrl = cover,
                detail = doc.optJSONArray("language")?.strings()?.firstOrNull()?.let(::editionName),
            )
        }
    }

    /** "en" / "eng" → "English edition"; unknown languages → null. */
    private fun editionName(code: String): String? {
        if (code.lowercase() in setOf("un", "und", "mul", "zxx")) return null
        val name = Locale.forLanguageTag(code).getDisplayLanguage(Locale.ENGLISH).ifEmpty { return null }
        return "${name.replaceFirstChar { it.uppercase() }} edition"
    }

    private fun encode(s: String) = URLEncoder.encode(s, "UTF-8")

    suspend fun get(url: String): String? = fetch(url)?.toString(Charsets.UTF_8)

    /** A cover or other image; tiny responses (placeholders) count as missing. */
    suspend fun download(url: String): ByteArray? = fetch(url)?.takeIf { it.size > 1_000 }

    private suspend fun fetch(url: String): ByteArray? = withContext(Dispatchers.IO) {
        runCatching {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 12_000
            c.readTimeout = 12_000
            c.setRequestProperty("User-Agent", "QuietReading/0.1 (Android)")
            try {
                if (c.responseCode == 200) c.inputStream.use { it.readBytes() } else null
            } finally { c.disconnect() }
        }.getOrNull()
    }
}

fun JSONArray.objects(): List<JSONObject> = (0 until length()).mapNotNull { optJSONObject(it) }
fun JSONArray.strings(): List<String> = (0 until length()).mapNotNull { optString(it).takeIf { s -> s.isNotEmpty() } }
