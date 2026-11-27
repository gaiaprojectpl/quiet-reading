import SwiftUI
import SwiftData
import WidgetKit
import CryptoKit

/// Writes what the widgets show (WidgetSnapshot + small covers) into the App Group,
/// then asks WidgetKit to redraw. Called whenever books, the goal or the theme change.
enum WidgetSync {
    static func update(books: [Book], goal: Int, theme: ThemeID, forceHighContrast: Bool, isPlus: Bool) {
        let reading = books.filter { $0.status == .reading }.sorted { $0.lastUpdated > $1.lastUpdated }
        let upNext = books.filter { $0.status == .toRead }.sorted { $0.lastUpdated > $1.lastUpdated }.prefix(3)
        let stats = ReadingStats(books: books)
        var keep: Set<String> = []

        func item(_ b: Book) -> WidgetSnapshot.BookItem {
            let id = encode(b.persistentModelID)
            let file = writeCover(b.coverData, id: id)
            if let file { keep.insert(file) }
            return .init(id: id, title: b.title, author: b.author, currentPage: b.currentPage,
                         pageCount: b.pageCount, minutesLeft: b.minutesLeft(), coverFile: file)
        }

        let snapshot = WidgetSnapshot(
            current: reading.first.map(item),
            upNext: upNext.map(item),
            goal: goal,
            finishedThisYear: stats.finished(in: stats.currentYear).count,
            year: stats.currentYear,
            theme: theme,
            forceHighContrast: forceHighContrast,
            isPlus: isPlus,
            weekPages: stats.thisWeek.map(\.pages))
        snapshot.save()
        cleanCovers(keeping: keep)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The book a widget link points to.
    static func book(for id: String, in context: ModelContext) -> Book? {
        guard let data = Data(base64URL: id),
              let pid = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
        return context.model(for: pid) as? Book
    }

    private static func encode(_ id: PersistentIdentifier) -> String {
        ((try? JSONEncoder().encode(id)) ?? Data()).base64URL
    }

    /// Small JPEG (widgets have a tight memory budget), named after the book and the cover's content.
    private static func writeCover(_ data: Data?, id _: String) -> String? {
        guard let data, let folder = WidgetSnapshot.coversFolder else { return nil }
        let name = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined() + ".jpg"
        let url = folder.appending(path: name)
        if FileManager.default.fileExists(atPath: url.path()) { return name }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let image = UIImage(data: data) else { return nil }
        let width: CGFloat = 240
        let size = CGSize(width: width, height: width * image.size.height / max(image.size.width, 1))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? small.write(to: url, options: .atomic)
        return name
    }

    private static func cleanCovers(keeping: Set<String>) {
        guard let folder = WidgetSnapshot.coversFolder,
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path()) else { return }
        for f in files where !keeping.contains(f) { try? FileManager.default.removeItem(at: folder.appending(path: f)) }
    }
}

/// Where a widget tap should take the reader (Home's Update sheet or a book's details).
@Observable
final class WidgetRouter {
    var updateBookID: String?
    var openBookID: String?
    var openAdd = false
    var openStats = false

    func handle(_ url: URL) {
        guard url.scheme == "quietreading" else { return }
        switch url.host() {
        case "book": openBookID = url.lastPathComponent
        case "add": openAdd = true
        case "stats": openStats = true
        default: break
        }
    }

    /// "+" / "Update" pressed on a widget (UpdateBookIntent left a note in the App Group).
    func checkPendingUpdate() {
        let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup)
        if let id = defaults?.string(forKey: "pendingUpdateBook") {
            defaults?.removeObject(forKey: "pendingUpdateBook")
            updateBookID = id
        }
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var s = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}
