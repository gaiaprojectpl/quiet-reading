import SwiftUI
import SwiftData

/// Flow 1 › Step 5 · Home: today's date, the book being read now, and what's up next.
struct HomeView: View {
    var onSeeAll: () -> Void = {}
    var onAddBook: () -> Void = {}
    var onImport: () -> Void = {}
    @Environment(\.theme) private var theme
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]
    @State private var updating: Book?
    @State private var finishing: Book?
    @State private var finishAfterSheet: Book?
    @State private var choosingNext = false
    #if DEBUG
    @State private var debugWhatNext = false
    @Environment(NotificationCenterModel.self) private var debugNotifications
    #endif
    @Environment(\.duoLayout) private var duo
    @Environment(\.modelContext) private var context
    @Environment(WidgetRouter.self) private var router
    @State private var path: [Book] = []

    private var current: Book? {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "qsNoCurrent") { return nil }   // test builds: -qsNoCurrent YES
        #endif
        return books.first { $0.status == .reading }
    }
    /// Everyone reads more than one book sometimes: the rest of the Reading shelf, most recent first.
    private var alsoReading: [Book] {
        guard let current else { return [] }
        return books.filter { $0.status == .reading && $0.persistentModelID != current.persistentModelID }
    }
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
                    .buttonStyle(QsButtonStyle(priority: .primary))
                Button("Import from Goodreads or StoryGraph", action: onImport)
                    .buttonStyle(QsButtonStyle(priority: .text))
            }
        } else {
            NavigationStack(path: $path) {
                Group {
                    switch duo.mode {
                    case .book: bookLayout
                    case .tabletop: tabletopLayout
                    case .phone, .single, .upright: phoneLayout
                    }
                }
                .background(theme.palette.bg.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            }
            .sheet(item: $updating, onDismiss: {
                // "Finished" in the sheet: show the Finished moment once the sheet has gone.
                if let book = finishAfterSheet { finishAfterSheet = nil; finishing = book }
            }) { book in
                UpdatePageSheet(book: book, onFinish: { finishAfterSheet = book })
            }
            .fullScreenCover(item: $finishing) { book in
                FinishFlow(book: book)
            }
            // From a widget: "+" / "Update" opens the page update; a tap on the book opens its details.
            .onChange(of: router.updateBookID, initial: true) { _, id in
                guard let id else { return }
                router.updateBookID = nil
                if let book = WidgetSync.book(for: id, in: context) { path = []; updating = book }
            }
            .onChange(of: router.openBookID, initial: true) { _, id in
                guard let id else { return }
                router.openBookID = nil
                if let book = WidgetSync.book(for: id, in: context) { path = [book] }
            }
            .fullScreenCover(isPresented: $choosingNext) {
                NavigationStack { WhatNextView(onDone: { choosingNext = false }) }
            }
            #if DEBUG
            // Test builds only: `-qsOpen update | finish | saved | whatnext`.
            .task {
                guard let current else { return }
                switch UserDefaults.standard.string(forKey: "qsOpen") {
                case "update": updating = current
                case "finish": finishing = current
                case "saved": debugNotifications.show("Page \(current.currentPage) saved", message: "About 2 h 50 min left. Lovely.", actionTitle: "Undo") {}
                case "whatnext": debugWhatNext = true
                default: break
                }
            }
            .fullScreenCover(isPresented: $debugWhatNext) {
                NavigationStack { WhatNextView(onDone: { debugWhatNext = false }) }
            }
            #endif
        }
    }

    // MARK: Layouts (Figma Flow 6b › Home)

    /// iPhone, and Duo closed: one column with Up next as cover tiles.
    private var phoneLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                header
                currentSection
                if !alsoReading.isEmpty { alsoReadingSection }
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
                    if !alsoReading.isEmpty { alsoReadingSection }
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
                    if !alsoReading.isEmpty { alsoReadingSection }
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
            BookActions(onUpdate: { updating = current }, onFinish: { finishing = current })
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
            CurrentBookCard(book: current, onUpdate: { updating = current }, onFinish: { finishing = current }, showsActions: !pinActions)
        } else {
            NothingInProgress(hasWantToRead: !upNext.isEmpty, onAddBook: onAddBook, onChoose: { choosingNext = true })
        }
    }

    /// "Also reading": the other books in progress, each with its own Update.
    private var alsoReadingSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Also reading")
                .font(theme.headline(20, relativeTo: .title3))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            QsListCard {
                ForEach(alsoReading) { book in
                    AlsoReadingRow(book: book, onUpdate: { updating = book })
                }
            }
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
                        NavigationLink(value: book) {
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
                        .buttonStyle(QsPressStyle())
                    }
                }
                .padding(.vertical, Space.s4) // room for the cover shadow
            }
            // Edge to edge of the app's area, never into the Duo's clock / Wi-Fi column.
            .contentMargins(.horizontal, Space.s20, for: .scrollContent)
            .padding(.horizontal, -Space.s20)
            .clipped()
        }
    }
}

/// One more book in progress: cover, title, progress, and its own Update. Tap the row for details.
private struct AlsoReadingRow: View {
    let book: Book
    let onUpdate: () -> Void
    @Environment(\.theme) private var theme

    private var progressLine: String {
        if let pages = book.pageCount, book.currentPage > 0 {
            return String(localized: "p. \(book.currentPage) of \(pages)")
        }
        return book.currentPage > 0 ? String(localized: "p. \(book.currentPage)") : String(localized: "Not started")
    }

    var body: some View {
        HStack(spacing: Space.s12) {
            NavigationLink(value: book) {
                HStack(spacing: Space.s12) {
                    BookCover(source: .data(book.coverData), title: book.title, width: Space.s40)
                    VStack(alignment: .leading, spacing: Space.s4) {
                        Text(book.title)
                            .font(theme.headline(17, relativeTo: .body))
                            .foregroundStyle(theme.palette.ink)
                            .lineLimit(2)
                        if let progress = book.progress, book.currentPage > 0 {
                            QsProgressBar(value: progress, size: .s)
                        }
                        Text(progressLine).font(.footnote).foregroundStyle(theme.palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(QsPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Open the book")
            Button("Update", action: onUpdate)
                .buttonStyle(QsButtonStyle(priority: .secondary, size: .small))
                .fixedSize()
                .accessibilityLabel(Text("Update \(book.title)"))
        }
        .padding(.horizontal, Space.s12)
        .padding(.vertical, Space.s12)
    }
}

/// Figma: Home › Current book card.
private struct CurrentBookCard: View {
    let book: Book
    let onUpdate: () -> Void
    let onFinish: () -> Void
    var showsActions = true
    @Environment(\.theme) private var theme

    /// "About 3 h 20 min left" – an estimate (typical pace until timed sessions exist).
    @ViewBuilder private var timeLeft: some View {
        if let minutes = book.minutesLeft(), minutes > 0 {
            Text(ReadingTime.left(minutes))
                .font(.footnote)
                .foregroundStyle(theme.palette.ink2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            // Tap the book (cover, title, progress) for its details; the buttons stay separate.
            NavigationLink(value: book) {
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
                        timeLeft
                    } else if let progress = book.progress, let pages = book.pageCount {
                        QsProgressBar(value: progress)
                        Text("p. \(book.currentPage) of \(pages) · \(progress, format: .percent.precision(.fractionLength(0)))")
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                            .contentTransition(.numericText())
                            .gentleAnimation(book.currentPage)
                        timeLeft
                    } else if book.currentPage > 0 {
                        Text("p. \(book.currentPage)")
                            .font(.footnote)
                            .foregroundStyle(theme.palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            }
            .buttonStyle(QsPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Open the book")
            if showsActions {
                BookActions(onUpdate: onUpdate, onFinish: onFinish)
            }
        }
        .padding(Space.s16)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }
}

/// Flow 10 › A4 · Home · nothing in progress: no streak warning, no pressure.
private struct NothingInProgress: View {
    let hasWantToRead: Bool
    let onAddBook: () -> Void
    let onChoose: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s20) {
            VStack(alignment: .leading, spacing: Space.s16) {
                HStack(alignment: .top, spacing: Space.s16) {
                    RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous)
                        .fill(theme.palette.disabledBg)
                        .frame(width: Size.coverM, height: Size.coverM * 1.5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Space.s8) {
                        Text("No book yet")
                            .font(theme.headline(20, relativeTo: .title3))
                            .foregroundStyle(theme.palette.ink)
                        Text("Add one by photographing its cover.")
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.ink2)
                    }
                }
                Button("Add a book", action: onAddBook)
                    .buttonStyle(QsButtonStyle(priority: .primary))
            }
            .padding(Space.s16)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
            if hasWantToRead {
                VStack(alignment: .leading, spacing: Space.s12) {
                    Text("You finished every book you were reading. Pick the next one from Want to read, or let it wait.")
                        .font(.subheadline)
                        .foregroundStyle(theme.palette.ink2)
                    Button("Choose from Want to read", action: onChoose)
                        .buttonStyle(QsButtonStyle(priority: .secondary))
                }
            }
        }
        .gentleAppear()
    }
}

/// Update + Finished for the current book. Finished opens the Finished moment (Flow 3 › Step 4).
private struct BookActions: View {
    let onUpdate: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: Space.s12) {
            Button("Update", action: onUpdate)
                .buttonStyle(QsButtonStyle(priority: .primary))
            Button("Finished", action: onFinish)
                .buttonStyle(QsButtonStyle(priority: .secondary))
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Book.self, inMemory: true)
}
