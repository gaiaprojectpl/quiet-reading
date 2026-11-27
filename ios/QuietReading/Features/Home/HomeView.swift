import SwiftUI
import SwiftData

/// Flow 1 › Step 5 · Home: today's date, the book being read now, and what's up next.
struct HomeView: View {
    var onSeeAll: () -> Void = {}
    var onAddBook: () -> Void = {}
    @Environment(\.theme) private var theme
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]
    @State private var updating: Book?
    @Environment(\.duoLayout) private var duo

    private var current: Book? { books.first { $0.status == .reading } }
    private var upNext: [Book] { Array(books.filter { $0.status == .toRead }.prefix(10)) }

    var body: some View {
        if books.isEmpty {
            ScreenScaffold(title: "Home") {
                EmptyStateView(
                    icon: "qs.book",
                    title: "Your shelf is ready",
                    message: "Add the book you’re reading now. It takes a few seconds."
                )
            } actions: {
                Button("Add a book", action: onAddBook)
                    .buttonStyle(QsButtonStyle(kind: .primary))
            }
        } else {
            NavigationStack {
                Group {
                    switch duo.mode {
                    case .book: bookLayout
                    case .tabletop: tabletopLayout
                    case .phone, .single, .upright: phoneLayout
                    }
                }
                .background(theme.palette.bg.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
            .sheet(item: $updating) { book in
                UpdatePageSheet(book: book)
            }
        }
    }

    // MARK: Layouts (Figma Flow 6b › Home)

    /// iPhone, and Duo closed: one column with Up next as cover tiles.
    private var phoneLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                header
                currentSection
                if !upNext.isEmpty { upNextSection }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s40)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if pinActions { pinnedActions } }
    }

    /// Duo open like a book: Reading now on the left page, Up next on the right page.
    private var bookLayout: some View {
        HStack(alignment: .top, spacing: duo.fold.width) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s20) {
                    header
                    currentSection
                }
                .padding(Space.s20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { pinnedActions }
            .frame(width: duo.fold.minX)
            ScrollView {
                if !upNext.isEmpty { upNextList }
            }
            .padding(.top, Space.s20)
            .frame(maxWidth: .infinity)
        }
    }

    /// Duo half-folded: the book you're reading on top, Up next below the fold.
    private var tabletopLayout: some View {
        VStack(spacing: duo.fold.height) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    Text("Reading now")
                        .font(theme.headline(28, relativeTo: .title))
                        .foregroundStyle(theme.palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    currentSection
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s48)
                .padding(.bottom, Space.s20)
            }
            .frame(height: duo.fold.minY)
            ScrollView {
                if !upNext.isEmpty { upNextList }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { pinnedActions }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Sections

    /// On iPhone Duo the navigation is a side rail, so Update / Finished are pinned to the bottom
    /// of the screen (or page) in every posture. On iPhone they stay in the card above the tab bar.
    private var pinActions: Bool { duo.mode != .phone }

    @ViewBuilder private var pinnedActions: some View {
        if let current {
            BookActions(book: current, onUpdate: { updating = current })
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s12)
                // Tabletop has the bottom tab bar below; elsewhere keep clear of the edge (placement rules).
                .padding(.bottom, duo.actionsBottom)
                .background(theme.palette.bg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s20) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.72)
                .foregroundStyle(theme.palette.ink2)
            Text("Reading now")
                .font(theme.headline(32, relativeTo: .largeTitle))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var currentSection: some View {
        if let current {
            CurrentBookCard(book: current, onUpdate: { updating = current }, showsActions: !pinActions)
        } else {
            InfoBanner(message: "No book in progress. Pick one from Up next or your library.")
        }
    }

    /// Up next as rows (Duo open and tabletop): small cover, title, author · pages.
    private var upNextList: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            upNextHeader
            ForEach(upNext) { book in
                HStack(spacing: Space.s16) {
                    BookCover(source: .data(book.coverData), title: book.title, width: Space.s40)
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text(book.title)
                            .font(theme.headline(17, relativeTo: .body))
                            .foregroundStyle(theme.palette.ink)
                        Text(book.pageCount.map { "\(book.author) · \($0) pages" } ?? book.author)
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.bottom, Space.s24)
    }

    private var upNextHeader: some View {
        HStack {
            Text("Up next")
                .font(theme.headline(20, relativeTo: .title3))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("See all", action: onSeeAll)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.palette.accentInk)
                .frame(minHeight: Size.touchIos)
        }
    }

    /// Figma: Books › Book grid cell (105 pt).
    private static let tileWidth: CGFloat = 105

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: Space.s20) {
            upNextHeader
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.s16) {
                    ForEach(upNext) { book in
                        VStack(alignment: .leading, spacing: Space.s8) {
                            BookCover(source: .data(book.coverData), title: book.title, width: Self.tileWidth)
                            Text(book.title)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(theme.palette.ink)
                                .lineLimit(2)
                                .frame(width: Self.tileWidth, alignment: .leading)
                            if let progress = book.progress, book.currentPage > 0 {
                                QsProgressBar(value: progress, size: .s)
                                    .frame(width: Self.tileWidth)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(book.title), \(book.author)"))
                    }
                }
                .padding(.vertical, Space.s4) // room for the cover shadow
            }
        }
    }
}

/// Figma: Home › Current book card.
private struct CurrentBookCard: View {
    let book: Book
    let onUpdate: () -> Void
    var showsActions = true
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack(alignment: .top, spacing: Space.s16) {
                BookCover(source: .data(book.coverData), title: book.title, width: 96)
                VStack(alignment: .leading, spacing: Space.s8) {
                    Text("READING NOW")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.66)
                        .foregroundStyle(theme.palette.ink2)
                    Text(book.title)
                        .font(theme.headline(21, relativeTo: .title3))
                        .foregroundStyle(theme.palette.ink)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.ink2)
                    }
                    if book.currentPage == 0, let pages = book.pageCount {
                        Text("\(pages) pages")
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                    } else if let progress = book.progress, let pages = book.pageCount {
                        QsProgressBar(value: progress)
                        Text("p. \(book.currentPage) of \(pages) · \(progress, format: .percent.precision(.fractionLength(0)))")
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                    } else if book.currentPage > 0 {
                        Text("p. \(book.currentPage)")
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            if showsActions {
                BookActions(book: book, onUpdate: onUpdate)
            }
        }
        .padding(Space.s16)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }
}

/// Update + Finished for the current book.
private struct BookActions: View {
    let book: Book
    let onUpdate: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: Space.s12) {
            Button("Update", action: onUpdate)
                .buttonStyle(QsButtonStyle(kind: .primary))
            Button("Finished") {
                book.status = .read
                book.dateFinished = .now
                if let pages = book.pageCount { book.currentPage = pages }
                book.lastUpdated = .now
                try? context.save()
            }
            .buttonStyle(QsButtonStyle(kind: .secondary))
        }
    }
}

/// Flow 3 › Step 2 · Update page: typed page (number keyboard opens straight away),
/// Finished + Update side by side, 16 pt above the keyboard (button placement rules).
private struct UpdatePageSheet: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var page: Int?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Where are you now?")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.s8) {
                Text("Page")
                    .font(.footnote)
                    .foregroundStyle(theme.palette.ink2)
                HStack {
                    TextField("Page", value: $page, format: .number)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.body)
                    if let pages = book.pageCount {
                        Text("of \(pages)")
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.ink2)
                    }
                }
                .padding(.horizontal, Space.s12)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Space.s12) {
                Button("Finished") {
                    book.status = .read
                    book.dateFinished = .now
                    if let pages = book.pageCount { book.currentPage = pages }
                    book.lastUpdated = .now
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(QsButtonStyle(kind: .secondary))
                Button("Update") {
                    if let page {
                        book.currentPage = max(0, book.pageCount.map { min(page, $0) } ?? page)
                        book.lastUpdated = .now
                        try? context.save()
                    }
                    dismiss()
                }
                .buttonStyle(QsButtonStyle(kind: .primary))
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s16)
            .padding(.bottom, QsLayout.actionsAboveBottomLine) // above the keyboard
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            page = book.currentPage > 0 ? book.currentPage : nil
            focused = true
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Book.self, inMemory: true)
}
