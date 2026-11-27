import Foundation
import AppIntents

/// What the widgets show, written by the app into the App Group and read by the widget extension.
/// The widget never goes online and never opens the database; the app writes, the widget reads.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    struct BookItem: Codable, Sendable, Identifiable, Hashable {
        /// Opaque id the app uses to find the book again (encoded SwiftData identifier).
        let id: String
        let title: String
        let author: String
        let currentPage: Int
        let pageCount: Int?
        let minutesLeft: Int?
        /// File name of a small cover JPEG in the App Group's covers folder.
        let coverFile: String?
        /// "Cover tone" colour (RRGGBB): the cover's own colour, deepened until white text reads at 4.5:1 or more.
        var coverTone: String? = nil

        var progress: Double? {
            guard let pageCount, pageCount > 0 else { return nil }
            return min(1, Double(currentPage) / Double(pageCount))
        }
    }

    struct QuoteItem: Codable, Sendable, Hashable {
        let text: String
        let book: String
        let page: Int?
    }

    var current: BookItem?
    var upNext: [BookItem] = []
    /// Quotes chosen for widgets (or the latest ones); the Quote widget shows one a day.
    var quotes: [QuoteItem] = []
    var goal = 0
    var finishedThisYear = 0
    var year = Calendar.current.component(.year, from: .now)
    var theme: ThemeID = .peachSage
    var forceHighContrast = false
    var isPlus = false
    var weekPages: [Int] = []
    var updated = Date.now

    // MARK: Storage

    static let appGroup = "group.app.quietreading"

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static var coversFolder: URL? { folder?.appending(path: "WidgetCovers", directoryHint: .isDirectory) }

    static func coverURL(_ file: String?) -> URL? {
        guard let file else { return nil }
        return coversFolder?.appending(path: file)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = folder?.appending(path: "widget.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.folder?.appending(path: "widget.json"),
              let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Shown in the widget gallery before the app has written anything.
    static let preview = WidgetSnapshot(
        current: BookItem(id: "preview", title: "Anne of Green Gables", author: "L. M. Montgomery",
                          currentPage: 142, pageCount: 310, minutesLeft: 200, coverFile: nil),
        upNext: [BookItem(id: "p1", title: "The Secret Garden", author: "Frances Hodgson Burnett", currentPage: 0, pageCount: 331, minutesLeft: nil, coverFile: nil),
                 BookItem(id: "p2", title: "Pride and Prejudice", author: "Jane Austen", currentPage: 0, pageCount: 432, minutesLeft: nil, coverFile: nil),
                 BookItem(id: "p3", title: "The Great Gatsby", author: "F. Scott Fitzgerald", currentPage: 0, pageCount: 180, minutesLeft: nil, coverFile: nil)],
        quotes: [QuoteItem(text: "Isn’t it nice to think that tomorrow is a new day with no mistakes in it yet?", book: "Anne of Green Gables", page: 98)],
        goal: 30, finishedThisYear: 18, isPlus: true, weekPages: [24, 0, 41, 18, 49, 0, 32])
}

/// Deep links the widgets open: `quietreading://book/<id>`, `quietreading://add`.
nonisolated enum WidgetLink {
    static func book(_ id: String) -> URL { URL(string: "quietreading://book/\(id)")! }
    static let add = URL(string: "quietreading://add")!
    static let stats = URL(string: "quietreading://stats")!
    static let plus = URL(string: "quietreading://plus")!
}

/// "+" / "Update" on a widget: opens the app straight into the page update (progress is always typed).
struct UpdateBookIntent: AppIntent {
    static let title: LocalizedStringResource = "Update my page"
    static let description = IntentDescription("Opens Quiet Reading to type the page you're on.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Book") var bookID: String

    init() {}
    init(bookID: String) { self.bookID = bookID }

    func perform() async throws -> some IntentResult {
        // The app picks this up when it becomes active (see WidgetRouter).
        UserDefaults(suiteName: WidgetSnapshot.appGroup)?.set(bookID, forKey: "pendingUpdateBook")
        return .result()
    }
}
