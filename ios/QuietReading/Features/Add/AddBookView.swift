import SwiftUI

struct AddBookView: View {
    var body: some View {
        ScreenScaffold(title: "Add a book") {
            EmptyStateView(
                icon: "qs.camera",
                title: "Three ways to add",
                message: "Photograph the cover, scan the barcode or search by title."
            )
            Button("Photograph the cover") {}
                .buttonStyle(QsButtonStyle(kind: .primary))
            Button("Scan the barcode") {}
                .buttonStyle(QsButtonStyle(kind: .secondary))
            Button("Search by title") {}
                .buttonStyle(QsButtonStyle(kind: .text))
        }
    }
}

#Preview { AddBookView() }
