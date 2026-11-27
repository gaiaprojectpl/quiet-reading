import Foundation

/// One edition found online, shown in "Is this the book?" and search results.
nonisolated struct BookCandidate: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var author: String
    var pageCount: Int?
    var isbn: String?
    var coverURL: URL?
    /// "English edition", "Polish edition", "Audiobook"…
    var detail: String?
}

/// Finds books online: Google Books first (editions, languages, covers), Open Library as a fallback.
/// Runs without an API key (fine for personal use; a key or a small server comes before release).
nonisolated enum BookSearch {
    static func search(_ query: String) async -> [BookCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var results = await googleBooks("q=\(encode(q))")
        if results.isEmpty { results = await openLibrary("q=\(encode(q))") }
        return rank(results, for: q)
    }

    /// Books whose title and author share the most words with the query come first (stable otherwise).
    private static func rank(_ results: [BookCandidate], for query: String) -> [BookCandidate] {
        let words = Set(query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 1 })
        guard !words.isEmpty else { return results }
        func score(_ c: BookCandidate) -> Double {
            let titleWords = Set(c.title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            let authorWords = Set(c.author.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            let hits = Double(words.intersection(titleWords).count) * 2 + Double(words.intersection(authorWords).count)
            let extra = Double(titleWords.subtracting(words).count)   // "cookbook", "retold", "study guide"…
            return hits - extra
        }
        return results.enumerated()
            .sorted { (score($0.element), -$0.offset) > (score($1.element), -$1.offset) }
            .map(\.element)
    }

    static func lookup(isbn: String) async -> [BookCandidate] {
        let google = await googleBooks("q=isbn:\(isbn)")
        if !google.isEmpty { return google }
        return await openLibrary("isbn=\(isbn)")
    }

    /// A cover for an ISBN: Open Library first, then Google Books.
    static func coverData(isbn: String?, fallbackURL: URL? = nil) async -> Data? {
        if let data = await CoverFetcher.cover(isbn: isbn) { return data }
        if let isbn, let url = await googleBooks("q=isbn:\(isbn)").first?.coverURL, let data = await download(url) { return data }
        if let fallbackURL { return await download(fallbackURL) }
        return nil
    }

    // MARK: Google Books

    private static func googleBooks(_ query: String) async -> [BookCandidate] {
        let fields = "items(id,volumeInfo(title,subtitle,authors,pageCount,language,printType,industryIdentifiers,imageLinks/thumbnail))"
        guard let url = URL(string: "https://www.googleapis.com/books/v1/volumes?\(query)&maxResults=12&printType=books&fields=\(fields)"),
              let data = await get(url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let info = item["volumeInfo"] as? [String: Any], let title = info["title"] as? String else { return nil }
            let ids = (info["industryIdentifiers"] as? [[String: String]]) ?? []
            let isbn = ids.first { $0["type"] == "ISBN_13" }?["identifier"] ?? ids.first { $0["type"] == "ISBN_10" }?["identifier"]
            let thumb = ((info["imageLinks"] as? [String: String])?["thumbnail"])?
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "&edge=curl", with: "")
            return BookCandidate(
                id: (item["id"] as? String) ?? UUID().uuidString,
                title: title,
                author: ((info["authors"] as? [String]) ?? []).joined(separator: ", "),
                pageCount: (info["pageCount"] as? Int).flatMap { $0 > 0 ? $0 : nil },
                isbn: isbn,
                coverURL: thumb.flatMap(URL.init(string:)),
                detail: (info["language"] as? String).flatMap(editionName)
            )
        }
    }

    // MARK: Open Library

    private static func openLibrary(_ query: String) async -> [BookCandidate] {
        guard let url = URL(string: "https://openlibrary.org/search.json?\(query)&limit=12&fields=key,title,author_name,isbn,number_of_pages_median,cover_i,language"),
              let data = await get(url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]] else { return [] }
        return docs.compactMap { doc in
            guard let title = doc["title"] as? String else { return nil }
            let isbn = (doc["isbn"] as? [String])?.first { $0.count == 13 } ?? (doc["isbn"] as? [String])?.first
            let cover = (doc["cover_i"] as? Int).flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") }
            let language = (doc["language"] as? [String])?.first
            return BookCandidate(
                id: (doc["key"] as? String) ?? UUID().uuidString,
                title: title,
                author: ((doc["author_name"] as? [String]) ?? []).prefix(2).joined(separator: ", "),
                pageCount: doc["number_of_pages_median"] as? Int,
                isbn: isbn,
                coverURL: cover,
                detail: language.flatMap(editionName)
            )
        }
    }

    // MARK: Helpers

    /// "en" / "eng" → "English edition"; unknown languages → nil.
    private static func editionName(_ code: String) -> String? {
        guard !["un", "und", "mul", "zxx"].contains(code.lowercased()) else { return nil }
        let short = code.count == 3 ? (Locale.LanguageCode(code).identifier(.alpha2) ?? code) : code
        let name = Locale.current.localizedString(forLanguageCode: short) ?? code
        return String(localized: "\(name.capitalized) edition")
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    private static func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("QuietReading/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    static func download(_ url: URL) async -> Data? {
        guard let data = await get(url), data.count > 1_000 else { return nil }
        return data
    }
}
