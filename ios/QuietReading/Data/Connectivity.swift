import Foundation
import Network
import Observation
import SwiftData

/// Knows whether the phone is online. Offline is never an error: saving always works,
/// and covers / details fill in later (Flow 10 › Offline & errors).
@Observable
final class Connectivity {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "qsOffline") { isOnline = false; return }   // test builds: -qsOffline YES
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "app.quietreading.connectivity"))
    }

    deinit { monitor.cancel() }
}

/// Fills in missing covers quietly – on launch and whenever the phone comes back online.
enum CoverBackfill {
    static func run(context: ModelContext) async {
        let books = ((try? context.fetch(FetchDescriptor<Book>())) ?? [])
            .filter { $0.coverData == nil && $0.isbn != nil }
            .prefix(20)
        for book in books {
            if let data = await BookSearch.coverData(isbn: book.isbn) {
                book.coverData = data
                try? context.save()
            }
        }
    }
}
