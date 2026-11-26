import SwiftUI

struct LibraryView: View {
    var body: some View {
        ScreenScaffold(title: "Library") {
            EmptyStateView(
                systemImage: "books.vertical",
                title: "Your library starts here",
                message: "Add books by photo, title or barcode, or bring them over from Goodreads."
            )
            Button("Add a book") {}
                .buttonStyle(QsButtonStyle(kind: .primary))
            Button("Import a library") {}
                .buttonStyle(QsButtonStyle(kind: .outline))
        }
    }
}

#Preview { LibraryView() }
