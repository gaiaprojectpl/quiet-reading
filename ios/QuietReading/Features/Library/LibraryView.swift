import SwiftUI

/// Flow 10 › A · Empty states › Library · empty.
struct LibraryView: View {
    var onAddBook: () -> Void = {}

    var body: some View {
        ScreenScaffold(title: "Library") {
            EmptyStateView(
                icon: "qs.library",
                title: "Your library starts here",
                message: "Add books by photo, title or barcode, or bring them over from Goodreads."
            )
        } actions: {
            Button("Add a book", action: onAddBook)
                .buttonStyle(QsButtonStyle(priority: .primary))
            Button("Import a library") {}
                .buttonStyle(QsButtonStyle(priority: .outline))
        }
    }
}

#Preview { LibraryView() }
