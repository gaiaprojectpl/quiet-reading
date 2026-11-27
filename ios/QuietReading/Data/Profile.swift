import SwiftUI
import UserNotifications
import SwiftData

/// The reader's profile, kept on this phone (accounts and sync come later).
nonisolated enum ProfileKeys {
    static let name = "profileName"
    static let handle = "profileHandle"
    static let about = "profileAbout"
    static let showOnWidgets = "profileShowOnWidgets"
    static let goal = "readingGoal"
    static let reminderOn = "reminderOn"
    static let reminderMinutes = "reminderMinutes"     // minutes after midnight
    static let appIcon = "appIcon"
    static let lastImport = "lastImportDate"
    static let lastImportSource = "lastImportSource"
}

/// Profile photo stored as a small JPEG in Application Support.
enum Avatar {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "avatar.jpg")
    }

    static func load() -> UIImage? {
        (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
    }

    static func save(_ image: UIImage?) {
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        if let data = image?.coverJPEG() { try? data.write(to: url) } else { try? FileManager.default.removeItem(at: url) }
    }
}

/// "Still with Anne of Green Gables?" – one gentle reminder a day, never more.
enum ReminderScheduler {
    static let id = "daily-reminder"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(minutes: Int, book: Book?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        if let book {
            content.title = String(localized: "Still with \(book.title)?")
            content.body = book.currentPage > 0
                ? String(localized: "You were on page \(book.currentPage). Tap to update.")
                : String(localized: "Tap to add your page.")
        } else {
            content.title = String(localized: "A quiet moment to read?")
            content.body = String(localized: "Your shelf is here when you are.")
        }
        var time = DateComponents()
        time.hour = minutes / 60
        time.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

/// Export (GDPR): books and quotes as CSV files the reader can save or share.
enum DataExport {
    static func files(books: [Book]) -> [URL] {
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let date = ISO8601DateFormatter()
        var csv = "Title,Author,ISBN13,Number of Pages,Shelf,Current Page,Date Added,Date Finished,My Rating,Moods\n"
        for b in books {
            csv += [esc(b.title), esc(b.author), esc(b.isbn ?? ""), b.pageCount.map(String.init) ?? "", esc(b.status.shelfName),
                    String(b.currentPage), date.string(from: b.dateAdded), b.dateFinished.map(date.string) ?? "",
                    (b.stars ?? b.rating.map(Double.init)).map { String($0) } ?? "", esc(b.moods.joined(separator: "; "))]
                .joined(separator: ",") + "\n"
        }
        var quotes = "Book,Author,Quote,Page,Feeling,Date\n"
        for b in books { for q in b.quotes {
            quotes += [esc(b.title), esc(b.author), esc(q.text), q.page.map(String.init) ?? "", esc(q.mood ?? ""), date.string(from: q.date)]
                .joined(separator: ",") + "\n"
        } }
        let dir = URL.temporaryDirectory
        let booksURL = dir.appending(path: "Quiet Reading – books.csv")
        let quotesURL = dir.appending(path: "Quiet Reading – quotes.csv")
        try? csv.write(to: booksURL, atomically: true, encoding: .utf8)
        try? quotes.write(to: quotesURL, atomically: true, encoding: .utf8)
        return [booksURL, quotesURL]
    }
}

/// Plus (one-time purchase). Flow 5 connects this to StoreKit; Plus themes and icons check it.
@Observable
final class PlusAccess {
    var isUnlocked: Bool {
        didSet { UserDefaults.standard.set(isUnlocked, forKey: "plusUnlocked") }
    }
    /// Set to show the Plus screen from anywhere (theme, icon, widgets).
    var showPaywall = false

    init() { isUnlocked = UserDefaults.standard.bool(forKey: "plusUnlocked") }
}
