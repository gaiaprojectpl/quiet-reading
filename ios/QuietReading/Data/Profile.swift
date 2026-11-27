import SwiftUI
import UserNotifications
import SwiftData
import StoreKit

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

/// Plus (one-time purchase, StoreKit 2). Plus themes, icons and the paywall check it.
/// The price always comes from the App Store (`displayPrice`), never from the app.
@Observable
final class PlusAccess {
    static let productID = "app.quietreading.plus"

    enum StoreState: Equatable { case loading, ready(price: String), unavailable }
    enum PurchaseResult { case unlocked, cancelled, pending, failed }
    enum RestoreResult { case restored, nothing, failed }

    var isUnlocked: Bool {
        didSet { UserDefaults.standard.set(isUnlocked, forKey: "plusUnlocked") }
    }
    /// Set to show the Plus screen from anywhere (theme, icon, widgets).
    var showPaywall = false
    /// A Plus theme the reader is trying on (Flow 5 › Live preview). Not saved.
    var previewTheme: ThemeID?
    private(set) var store: StoreState = .loading
    private(set) var isBusy = false

    private var product: Product?
    private var updates: Task<Void, Never>?

    init() {
        isUnlocked = UserDefaults.standard.bool(forKey: "plusUnlocked")
        #if DEBUG
        if UserDefaults.standard.object(forKey: "qsPlus") != nil { isUnlocked = UserDefaults.standard.bool(forKey: "qsPlus") }
        #endif
        // Purchases approved later (Ask to Buy), refunds and purchases on another device.
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates { self?.apply(result) }
        }
        Task { await refreshEntitlement() }
    }

    func loadProduct() async {
        if case .ready = store, product != nil || Self.stub != nil { return }
        store = .loading
        #if DEBUG
        if let stub = Self.stub {
            try? await Task.sleep(for: .milliseconds(400))
            store = stub == "none" ? .unavailable : .ready(price: "$4.99")
            return
        }
        #endif
        // Give the store 8 seconds, then offer a way out.
        let loaded = await withTaskGroup(of: Product?.self) { group in
            group.addTask { try? await Product.products(for: [Self.productID]).first }
            group.addTask { try? await Task.sleep(for: .seconds(8)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        product = loaded
        store = loaded.map { .ready(price: $0.displayPrice) } ?? .unavailable
    }

    func purchase() async -> PurchaseResult {
        isBusy = true
        defer { isBusy = false }
        #if DEBUG
        if let stub = Self.stub {
            try? await Task.sleep(for: .seconds(1))
            switch stub {
            case "fail": return .failed
            case "pending": return .pending
            default: isUnlocked = true; return .unlocked
            }
        }
        #endif
        guard let product else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                isUnlocked = true
                return .unlocked
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async -> RestoreResult {
        isBusy = true
        defer { isBusy = false }
        #if DEBUG
        if let stub = Self.stub {
            try? await Task.sleep(for: .seconds(1))
            if stub == "restore" { isUnlocked = true; return .restored }
            return .nothing
        }
        #endif
        do { try await AppStore.sync() } catch { return .failed }
        await refreshEntitlement()
        return isUnlocked ? .restored : .nothing
    }

    private func refreshEntitlement() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                isUnlocked = true
            }
        }
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) {
        guard case .verified(let t) = result, t.productID == Self.productID else { return }
        isUnlocked = t.revocationDate == nil
        Task { await t.finish() }
    }

    /// Test builds only: `-qsStore ready | none | fail | pending | restore` fakes the App Store.
    private static var stub: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "qsStore")
        #else
        nil
        #endif
    }
}
