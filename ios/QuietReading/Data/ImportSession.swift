import Foundation
import Observation
import SwiftData

/// Runs one import: reads the file, saves the books, then looks up covers in the background.
/// Lives at app level so "Continue in the background" keeps it running.
@Observable
final class ImportSession {
    enum Phase: Equatable {
        case idle, matching, finished, failed
    }

    private(set) var phase: Phase = .idle
    private(set) var total = 0
    private(set) var done = 0
    private(set) var missingCovers = 0
    /// The last few covers found, shown as thumbnails while matching.
    private(set) var recentCovers: [Data] = []
    /// "Goodreads" / "StoryGraph", for "214 books from Goodreads".
    private(set) var sourceName = ""
    private var startedMatching = Date.now
    private var task: Task<Void, Never>?

    /// Rough time left, from the pace so far ("about a minute left").
    var timeLeftText: String? {
        guard phase == .matching, done > 3 else { return nil }
        let perBook = Date.now.timeIntervalSince(startedMatching) / Double(done)
        let seconds = perBook * Double(total - done)
        if seconds < 45 { return String(localized: "less than a minute left") }
        if seconds < 90 { return String(localized: "about a minute left") }
        return String(localized: "about \(Int((seconds / 60).rounded())) minutes left")
    }

    func start(fileURL: URL, context: ModelContext) {
        task?.cancel()
        total = 0; done = 0; missingCovers = 0; recentCovers = []

        let access = fileURL.startAccessingSecurityScopedResource()
        defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: fileURL),
              let imported = try? LibraryCSV.parse(data) else {
            phase = .failed
            return
        }

        let existing = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        var known = Set(existing.map(\.matchKey))
        var added: [Book] = []
        for item in imported {
            let book = Book(
                title: item.title, author: item.author, isbn: item.isbn, pageCount: item.pageCount,
                currentPage: item.status == .read ? (item.pageCount ?? 0) : 0,
                status: item.status, source: item.source, rating: item.rating, dateFinished: item.dateFinished
            )
            guard known.insert(book.matchKey).inserted else { continue }
            context.insert(book)
            added.append(book)
        }
        try? context.save()

        total = added.count
        sourceName = imported.first.map { $0.source == .storyGraph ? "StoryGraph" : "Goodreads" } ?? ""
        startedMatching = .now
        phase = added.isEmpty ? .finished : .matching
        guard !added.isEmpty else { return }
        task = Task { await matchCovers(added, context: context) }
    }

    private func matchCovers(_ books: [Book], context: ModelContext) async {
        // Four at a time keeps Open Library happy and the import quick.
        for start in stride(from: 0, to: books.count, by: 4) {
            if Task.isCancelled { return }
            let chunk = Array(books[start..<min(start + 4, books.count)])
            let isbns = chunk.map(\.isbn)
            let results = await withTaskGroup(of: (Int, Data?).self) { group in
                for (i, isbn) in isbns.enumerated() {
                    // Open Library first, Google Books when it has nothing.
                    group.addTask { (i, await BookSearch.coverData(isbn: isbn)) }
                }
                var out = [Data?](repeating: nil, count: isbns.count)
                for await (i, data) in group { out[i] = data }
                return out
            }
            for (book, data) in zip(chunk, results) {
                if let data {
                    book.coverData = data
                    recentCovers = Array((recentCovers + [data]).suffix(4))
                } else {
                    missingCovers += 1
                }
                done += 1
            }
            try? context.save()
        }
        phase = .finished
    }
}

/// Looks up a cover on Open Library by ISBN. Returns nil when there is none or the phone is offline.
nonisolated enum CoverFetcher {
    static func cover(isbn: String?) async -> Data? {
        guard let isbn, let url = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg?default=false") else {
            return nil
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count > 1_000 else {
            return nil
        }
        return data
    }
}
