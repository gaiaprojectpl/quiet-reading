import SwiftUI

/// Flow 2 › Step 2 · Add a book: a short sheet from the bottom with the three ways to add.
/// Photo, barcode and search open their own screens in Flow 2 (not built yet).
struct AddBookView: View {
    @Environment(\.theme) private var theme
    @State private var height: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Add a book")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            QsListCard {
                QsListRow(icon: "qs.camera", title: "Photograph the cover",
                          subtitle: "Read on your phone, nothing uploaded") {}
                QsListRow(icon: "qs.barcode", title: "Scan the barcode") {}
                QsListRow(icon: "qs.search", title: "Search by title or author") {}
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.palette.bg.ignoresSafeArea())
        // The sheet is only as tall as its content, so it sits at the bottom within thumb reach.
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) { AddBookView() }
}
