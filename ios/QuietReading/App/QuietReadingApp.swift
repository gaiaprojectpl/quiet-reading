import SwiftUI
import SwiftData

@main
struct QuietReadingApp: App {
    init() {
        QsFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Book.self)
    }
}
