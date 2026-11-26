import SwiftUI

struct HomeView: View {
    var body: some View {
        ScreenScaffold(title: "Home") {
            EmptyStateView(
                systemImage: "book",
                title: "Your shelf is ready",
                message: "Add the book you’re reading now. It takes a few seconds."
            )
            Button("Add a book") {}
                .buttonStyle(QsButtonStyle(kind: .primary))
            Button("Import from Goodreads or StoryGraph") {}
                .buttonStyle(QsButtonStyle(kind: .text))
        }
    }
}

#Preview { HomeView() }
