import Foundation

/// Flow 12 · Explore: finds books the reader doesn't know yet.
/// The catalogue is Open Library (free, no key, works out of the box): search, genre (subjects),
/// length, published year, author and language, sorted by how many readers want to read each book.
/// Google Books fills in a description when Open Library has none.
/// (Hardcover needs a personal token that can't ship in the app; it comes with the backend.)
nonisolated struct ExploreBook: Identifiable, Hashable, Sendable {
    /// Open Library work key, e.g. "/works/OL66554W".
    let id: String
    let title: String
    let author: String
    let year: Int?
    let pages: Int?
    let coverID: Int?
    let isbn: String?
    let rating: Double?
    let ratingsCount: Int?
    let subjects: [String]

    var coverURL: URL? { coverID.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") } }
    var largeCoverURL: URL? { coverID.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg") } }

    /// "Jane Austen · 1817 · 272 pages"
    var detailLine: String {
        [author.isEmpty ? nil : author, year.map(String.init), pages.map { String(localized: "\($0) pages") }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Up to two of our genres that this book belongs to.
    var genres: [ExploreGenre] {
        let lower = subjects.map { $0.lowercased() }
        return ExploreGenre.allCases.filter { g in lower.contains { s in g.matchWords.contains { s.contains($0) } } }.prefix(2).map { $0 }
    }
}

nonisolated enum ExploreGenre: String, CaseIterable, Identifiable, Sendable {
    case classics, romance, fantasy, mystery, poetry, nonFiction, shortStories, historical
    var id: String { rawValue }

    var title: String {
        switch self {
        case .classics: String(localized: "Classics")
        case .romance: String(localized: "Romance")
        case .fantasy: String(localized: "Fantasy")
        case .mystery: String(localized: "Mystery")
        case .poetry: String(localized: "Poetry")
        case .nonFiction: String(localized: "Non-fiction")
        case .shortStories: String(localized: "Short stories")
        case .historical: String(localized: "Historical")
        }
    }

    /// Open Library subject query for this genre.
    var query: String {
        switch self {
        case .classics: "subject:classics"
        case .romance: "subject:romance"
        case .fantasy: "subject:fantasy"
        case .mystery: "subject:mystery"
        case .poetry: "subject:poetry"
        case .nonFiction: "subject_key:nonfiction"
        case .shortStories: "subject_key:short_stories"
        case .historical: "subject_key:historical_fiction"
        }
    }

    fileprivate var matchWords: [String] {
        switch self {
        case .classics: ["classic"]
        case .romance: ["romance", "love stories"]
        case .fantasy: ["fantasy"]
        case .mystery: ["mystery", "detective"]
        case .poetry: ["poetry", "poems"]
        case .nonFiction: ["nonfiction", "non-fiction", "biography"]
        case .shortStories: ["short stories"]
        case .historical: ["historical fiction", "historical"]
        }
    }
}

nonisolated struct ExploreFilters: Equatable, Sendable {
    enum Length: String, CaseIterable, Sendable { case any, under300, over300 }
    enum Published: String, CaseIterable, Sendable { case any, before1900, from1900, since2000 }
    enum Language: String, CaseIterable, Sendable { case english, any }

    var genres: Set<ExploreGenre> = []
    var length: Length = .any
    var published: Published = .any
    var author: String? = nil
    var language: Language = .english

    /// How many filters the reader chose (language English is the default, not a filter).
    var count: Int {
        genres.count + (length == .any ? 0 : 1) + (published == .any ? 0 : 1) + (author == nil ? 0 : 1) + (language == .english ? 0 : 1)
    }
    var isEmpty: Bool { count == 0 }

    fileprivate var clauses: [String] {
        var q = genres.sorted { $0.rawValue < $1.rawValue }.map(\.query)
        switch length {
        case .any: break
        case .under300: q.append("number_of_pages_median:[1 TO 299]")
        case .over300: q.append("number_of_pages_median:[300 TO *]")
        }
        switch published {
        case .any: break
        case .before1900: q.append("first_publish_year:[* TO 1899]")
        case .from1900: q.append("first_publish_year:[1900 TO 1999]")
        case .since2000: q.append("first_publish_year:[2000 TO *]")
        }
        if let author { q.append("author:\"\(author.replacingOccurrences(of: "\"", with: ""))\"") }
        if language == .english { q.append("language:eng") }
        return q
    }
}

nonisolated enum ExploreSort: String, CaseIterable, Sendable {
    case bestMatch, mostRead, topRated, newest, oldest
    var title: String {
        switch self {
        case .bestMatch: String(localized: "Best match")
        case .mostRead: String(localized: "Most read")
        case .topRated: String(localized: "Top rated")
        case .newest: String(localized: "Newest")
        case .oldest: String(localized: "Oldest")
        }
    }
    fileprivate var param: String {
        switch self {
        case .bestMatch: ""
        case .mostRead: "readinglog"
        case .topRated: "rating"
        case .newest: "new"
        case .oldest: "old"
        }
    }
}

nonisolated enum ExploreError: Error, Sendable { case offline, failed }

nonisolated enum ExploreCatalog {
    struct Page: Sendable { let books: [ExploreBook]; let total: Int }

    private static let fields = "key,title,author_name,first_publish_year,number_of_pages_median,cover_i,isbn,ratings_average,ratings_count,subject"

    /// One page of results (20). `text` can be a title, author or ISBN.
    static func search(text: String, filters: ExploreFilters, sort: ExploreSort, page: Int = 1, limit: Int = 20) async throws -> Page {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var clauses = filters.clauses
        let digits = t.filter(\.isNumber)
        if !t.isEmpty {
            if (digits.count == 10 || digits.count == 13), digits.count >= t.count - 4 { clauses.insert("isbn:\(digits)", at: 0) }
            else { clauses.insert("(\(t.replacingOccurrences(of: ":", with: " ")))", at: 0) }
        }
        if clauses.isEmpty { clauses = ["subject:fiction"] }
        var c = URLComponents(string: "https://openlibrary.org/search.json")!
        // Best match = Open Library's relevance (no sort); without typed text it means Most read.
        let sortParam = sort == .bestMatch && t.isEmpty ? ExploreSort.mostRead.param : sort.param
        c.queryItems = (sortParam.isEmpty ? [] : [URLQueryItem(name: "sort", value: sortParam)]) + [
            .init(name: "q", value: clauses.joined(separator: " AND ")),
            .init(name: "fields", value: fields),
            .init(name: "limit", value: String(limit)),
            .init(name: "page", value: String(page)),
            .init(name: "lang", value: "en"),
        ]
        let data = try await get(c.url!)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]] else { throw ExploreError.failed }
        let books = docs.compactMap(book)
        return Page(books: books, total: (json["numFound"] as? Int) ?? books.count)
    }

    /// Just the number of matches (the filter sheet's "Show 24 books").
    static func count(text: String, filters: ExploreFilters) async -> Int? {
        try? await search(text: text, filters: filters, sort: .mostRead, limit: 0).total
    }

    /// A book's description: Open Library's work, otherwise Google Books.
    static func description(for book: ExploreBook) async -> String? {
        if let url = URL(string: "https://openlibrary.org\(book.id).json"),
           let data = try? await get(url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let raw = (json["description"] as? String) ?? ((json["description"] as? [String: Any])?["value"] as? String)
            if let text = raw.map(clean), !text.isEmpty { return text }
        }
        var c = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        c.queryItems = [.init(name: "q", value: book.isbn.map { "isbn:\($0)" } ?? "intitle:\(book.title) inauthor:\(book.author)"),
                        .init(name: "maxResults", value: "1"), .init(name: "fields", value: "items(volumeInfo/description)")]
        if let data = try? await get(c.url!),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let desc = ((json["items"] as? [[String: Any]])?.first?["volumeInfo"] as? [String: Any])?["description"] as? String {
            return clean(desc)
        }
        return nil
    }

    // MARK: Helpers

    private static func book(_ doc: [String: Any]) -> ExploreBook? {
        guard let key = doc["key"] as? String, let title = doc["title"] as? String else { return nil }
        let isbns = (doc["isbn"] as? [String]) ?? []
        return ExploreBook(
            id: key, title: title,
            author: ((doc["author_name"] as? [String]) ?? []).prefix(2).map(latinName).joined(separator: ", "),
            year: doc["first_publish_year"] as? Int,
            pages: doc["number_of_pages_median"] as? Int,
            coverID: doc["cover_i"] as? Int,
            isbn: isbns.first { $0.hasPrefix("978") } ?? isbns.first,
            rating: doc["ratings_average"] as? Double,
            ratingsCount: doc["ratings_count"] as? Int,
            subjects: Array(((doc["subject"] as? [String]) ?? []).prefix(40)))
    }

    /// "孙武 (Sun Tzu)" → "Sun Tzu": the app is English, so prefer the Latin form when there is one.
    private static func latinName(_ name: String) -> String {
        guard name.unicodeScalars.contains(where: { $0.value > 0x2E7F }),
              let open = name.firstIndex(of: "("), let close = name.lastIndex(of: ")"), open < close else { return name }
        let inner = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return inner.unicodeScalars.allSatisfy({ $0.value < 0x2E80 }) && !inner.isEmpty ? inner : name
    }

    /// Strips Open Library's markdown links, source notes and extra blank lines.
    private static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\r", with: "")
        t = t.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        if let r = t.range(of: "\n----") { t = String(t[..<r.lowerBound]) }
        if let r = t.range(of: "([source]") { t = String(t[..<r.lowerBound]) }
        t = t.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated(unsafe) private static let cache = NSCache<NSURL, NSData>()   // NSCache is thread-safe

    private static func get(_ url: URL) async throws -> Data {
        if let hit = cache.object(forKey: url as NSURL) { return hit as Data }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("QuietReading/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ExploreError.failed }
            cache.setObject(data as NSData, forKey: url as NSURL)
            return data
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(error.code) {
            throw ExploreError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch let e as ExploreError {
            throw e
        } catch {
            throw ExploreError.failed
        }
    }
}
