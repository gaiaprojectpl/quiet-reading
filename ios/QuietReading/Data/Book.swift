import Foundation
import SwiftData

/// Where a book is on the reader's shelf.
nonisolated enum ReadingStatus: String, Codable, CaseIterable, Sendable {
    case reading, toRead, read, stopped
}

/// Where a book came from. Kept so a later re-import can skip duplicates.
nonisolated enum BookSource: String, Codable, Sendable {
    case goodreads, storyGraph, manual
}

/// One book on the reader's shelf. Stored on this phone with SwiftData.
/// (Moves into the App Group container when the widgets are built.)
@Model
final class Book {
    var title: String
    var author: String
    var isbn: String?
    var pageCount: Int?
    var currentPage: Int
    var statusRaw: String
    var sourceRaw: String
    var rating: Int?
    var dateAdded: Date
    var dateFinished: Date?
    var lastUpdated: Date
    @Attribute(.externalStorage) var coverData: Data?
    /// 0.5–5 in half stars, set at the Finished moment.
    var stars: Double?
    /// "How did it feel?" chips chosen at the Finished moment.
    var moods: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession] = []

    init(
        title: String, author: String, isbn: String? = nil, pageCount: Int? = nil,
        currentPage: Int = 0, status: ReadingStatus = .toRead, source: BookSource = .manual,
        rating: Int? = nil, dateFinished: Date? = nil
    ) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.statusRaw = status.rawValue
        self.sourceRaw = source.rawValue
        self.rating = rating
        self.dateAdded = .now
        self.dateFinished = dateFinished
        self.lastUpdated = .now
        self.coverData = nil
    }

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRaw) ?? .toRead }
        set { statusRaw = newValue.rawValue }
    }

    /// 0…1, or nil when the page count is unknown.
    var progress: Double? {
        guard let pageCount, pageCount > 0 else { return nil }
        return min(1, Double(currentPage) / Double(pageCount))
    }

    /// Average minutes per page: from timed sessions when there are any, otherwise a typical adult pace.
    var minutesPerPage: Double {
        let timed = sessions.filter { ($0.minutes ?? 0) > 0 && $0.toPage > $0.fromPage }
        let pages = timed.reduce(0) { $0 + ($1.toPage - $1.fromPage) }
        let minutes = timed.reduce(0) { $0 + ($1.minutes ?? 0) }
        return pages > 0 ? Double(minutes) / Double(pages) : 1.2
    }

    /// Estimated minutes left, nil when the page count is unknown.
    func minutesLeft(fromPage page: Int? = nil) -> Int? {
        guard let pageCount else { return nil }
        let left = max(0, pageCount - (page ?? currentPage))
        return Int((Double(left) * minutesPerPage).rounded())
    }

    /// Used to skip books that are already on the shelf.
    var matchKey: String {
        if let isbn, !isbn.isEmpty { return "isbn:\(isbn)" }
        return "t:\(title.lowercased())|\(author.lowercased())"
    }
}

/// One progress update: from page → to page, optionally how long and a note.
@Model
final class ReadingSession {
    var date: Date
    var fromPage: Int
    var toPage: Int
    var minutes: Int?
    var note: String?
    var book: Book?

    init(date: Date = .now, fromPage: Int, toPage: Int, minutes: Int? = nil, note: String? = nil) {
        self.date = date
        self.fromPage = fromPage
        self.toPage = toPage
        self.minutes = minutes
        self.note = note
    }
}

/// "About 3 h 20 min left"
nonisolated enum ReadingTime {
    static func left(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let text = h > 0 ? (m > 0 ? "\(h) h \(m) min" : "\(h) h") : "\(max(m, 1)) min"
        return String(localized: "About \(text) left")
    }
}
