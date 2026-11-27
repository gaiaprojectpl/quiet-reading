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

    /// Used to skip books that are already on the shelf.
    var matchKey: String {
        if let isbn, !isbn.isEmpty { return "isbn:\(isbn)" }
        return "t:\(title.lowercased())|\(author.lowercased())"
    }
}
