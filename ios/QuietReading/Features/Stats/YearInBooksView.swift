import SwiftUI

/// Flow 8 › Your 2026 in books: covers, a few numbers, the favourite, and a card made to share.
struct YearInBooksView: View {
    let stats: ReadingStats
    let year: Int
    var onOpen: (Book) -> Void = { _ in }
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    @AppStorage(ProfileKeys.name) private var name = ""
    @State private var shareImage: Image?

    private var books: [Book] { stats.finished(in: year) }

    private var line: String {
        String(localized: "\(books.count) books · \(stats.pages(in: year).formatted()) pages · \(stats.newAuthors(in: year)) new authors")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                HStack { QsBackButton(title: "Stats"); Spacer() }
                ScreenTitle(title: "Your \(String(year)) in books")
                Text(line).font(.subheadline).foregroundStyle(theme.palette.ink2)
                if books.isEmpty {
                    EmptyStateView(icon: "qs.calendar", title: "Your year is still being written",
                                   message: "Books you finish this year gather here, ready to share.")
                        .padding(.top, Space.s40)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s12), count: 3), spacing: Space.s12) {
                    ForEach(books) { book in
                        Button { onOpen(book) } label: {
                            BookCover(source: .data(book.coverData), title: book.title, width: nil)
                        }
                        .buttonStyle(QsPressStyle())
                        .accessibilityLabel(book.title)
                    }
                }
                if let fav = stats.favourite(in: year) {
                    HStack(spacing: Space.s12) {
                        BookCover(source: .data(fav.coverData), title: fav.title, width: Size.coverS)
                        VStack(alignment: .leading, spacing: Space.s2) {
                            Text("Favourite").textCase(.uppercase).font(.caption2.weight(.semibold)).foregroundStyle(theme.palette.ink2)
                            Text(fav.title).font(theme.headline(18, relativeTo: .headline)).foregroundStyle(theme.palette.ink)
                            Text(favouriteLine(fav)).font(.footnote).foregroundStyle(theme.palette.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Space.s12)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous).strokeBorder(theme.palette.line))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if let shareImage, !books.isEmpty {
                    ShareLink(item: shareImage, preview: SharePreview(String(localized: "My \(String(year)) in books"), image: shareImage)) {
                        HStack(spacing: Space.s8) {
                            Image("qs.share").resizable().frame(width: Size.iconM, height: Size.iconM).accessibilityHidden(true)
                            Text("Share")
                        }
                    }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { render() }
    }

    private func favouriteLine(_ book: Book) -> String {
        let stars = (book.stars ?? book.rating.map(Double.init)).map { "★ " + $0.formatted(.number.precision(.fractionLength(0...1))) }
        let mood = stats.topMood(in: year).map { String(localized: "most felt: \($0)") }
        return [stars, mood].compactMap { $0 }.joined(separator: " · ")
    }

    /// Draws the share card once (covers + "Ola read 18 books in 2026").
    private func render() {
        let card = ShareCard(books: Array(books.prefix(3)), title: name.isEmpty
            ? String(localized: "I read \(books.count) books in \(String(year))")
            : String(localized: "\(name) read \(books.count) books in \(String(year))"))
            .environment(\.theme, theme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = displayScale
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

/// The image that gets shared: soft card, three covers, one sentence, the app name.
private struct ShareCard: View {
    let books: [Book]
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(spacing: Space.s8) {
                ForEach(books) { BookCover(source: .data($0.coverData), title: $0.title, width: Size.coverM - Space.s8) }
            }
            Text(title).font(theme.headline(24, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
            Text("Quiet Reading").font(.caption.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
        }
        .padding(Space.s24)
        .frame(width: 360, alignment: .leading)
        .background(theme.palette.soft)
    }
}
