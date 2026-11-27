import SwiftUI
import SwiftData

/// Flow 7 › Step 1 · Library: shelves with counts, a 3-column grid, search, sort & filter.
/// On the open iPhone Duo the selected book's details sit on the right page.
struct LibraryView: View {
    var onAddBook: () -> Void = {}
    var onImport: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var books: [Book]

    @State private var shelf: ReadingStatus = .reading
    @State private var searching = false
    @State private var query = ""
    @State private var filter = LibraryFilter()
    @State private var showFilter = false
    @State private var path: [Book] = []
    @State private var selected: Book?
    @State private var pickedInitialShelf = false

    var body: some View {
        if books.isEmpty {
            emptyLibrary
        } else if duo.mode == .book {
            HStack(spacing: duo.fold.width) {
                NavigationStack { shelves }
                    .frame(width: duo.fold.minX)
                Group {
                    if let selected, books.contains(selected) {
                        NavigationStack {
                            BookDetailView(book: selected, showsBack: false, onRemoved: { self.selected = nil })
                        }
                        .id(selected.persistentModelID)
                    } else {
                        DuoIllustrationPage()
                    }
                }
            }
            .background(theme.palette.bg.ignoresSafeArea())
        } else {
            NavigationStack(path: $path) {
                shelves
                    .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            }
        }
    }

    // MARK: Library with books

    private var shelves: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                topIcons
                ScreenTitle(title: "Library")
                if searching { searchField }
                shelfChips
                content
                    .gentleAnimation(shelf)
                    .gentleAnimation(filter)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilter) {
            SortFilterSheet(filter: $filter, books: books, shelf: shelf)
        }
        .onAppear(perform: pickInitialShelf)
        #if DEBUG
        // Test builds only: `-qsLibrary detail | move | sort | empty | search`.
        .task {
            switch UserDefaults.standard.string(forKey: "qsLibrary") {
            case "detail", "move": if let b = books.first(where: { $0.status == .reading }) { open(b) }
            case "sort": showFilter = true
            case "empty": shelf = .stopped
            case "search": searching = true; query = "tolkien"
            default: break
            }
        }
        #endif
    }

    private var topIcons: some View {
        HStack(spacing: 0) {
            Spacer()
            iconButton("qs.search", label: searching ? "Close search" : "Search") {
                searching.toggle()
                if !searching { query = "" }
            }
            iconButton("qs.sort", label: "Sort and filter") { showFilter = true }
        }
    }

    private func iconButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: Size.iconL, height: Size.iconL)
                .foregroundStyle(theme.palette.ink)
                .frame(width: Size.touchIos, height: Size.touchIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("Search")
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.palette.ink2)
            HStack(spacing: Space.s8) {
                Image("qs.search")
                    .resizable()
                    .frame(width: Size.iconM, height: Size.iconM)
                    .foregroundStyle(theme.palette.ink2)
                    .accessibilityHidden(true)
                TextField("Title or author", text: $query)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }
            .padding(.horizontal, Space.s16)
            .frame(minHeight: Size.field)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
        }
    }

    private var shelfChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s8) {
                    ForEach(ReadingStatus.shelves, id: \.self) { s in
                        QsChip(title: "\(s.shelfName) \(count(s))", isSelected: shelf == s) { shelf = s }
                            .id(s)
                    }
                }
            }
            .scrollClipDisabled()
            // Keep the selected shelf in view, gliding to it.
            .onChange(of: shelf, initial: true) { _, s in
                withAnimation(reduceMotion ? nil : .easeOut(duration: Motion.base)) { proxy.scrollTo(s, anchor: .center) }
            }
        }
    }

    @ViewBuilder private var content: some View {
        let visible = visibleBooks
        if visible.isEmpty {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                noResults
            } else {
                EmptyShelf(shelf: shelf)
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s12, alignment: .top), count: 3),
                      alignment: .leading, spacing: Space.s16) {
                ForEach(visible) { book in
                    Button { open(book) } label: { LibraryTile(book: book) }
                        .buttonStyle(QsPressStyle())
                }
            }
            .transition(.opacity)
        }
    }

    /// Flow 7 › No search results.
    private var noResults: some View {
        VStack(spacing: Space.s12) {
            Image("qs.search")
                .resizable()
                .frame(width: Space.s40, height: Space.s40)
                .foregroundStyle(theme.palette.ink)
                .accessibilityHidden(true)
            Text("No books match “\(query)”")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
            Text("Check the spelling, or add the book by photographing its cover.")
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink2)
                .multilineTextAlignment(.center)
            Button(action: onAddBook) {
                Label { Text("Add by photo") } icon: { Image("qs.camera").resizable().frame(width: Size.iconM, height: Size.iconM) }
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .padding(.top, Space.s4)
        }
        .padding(.top, Space.s40)
        .frame(maxWidth: .infinity)
    }

    // MARK: Empty library (no books at all) – Flow 10 › Library · empty

    private var emptyLibrary: some View {
        ScreenScaffold(title: "Library") {
            EmptyStateView(
                icon: "qs.library",
                title: "Your library starts here",
                message: "Add books by photo, title or barcode, or bring them over from Goodreads."
            )
        } actions: {
            Button("Add a book", action: onAddBook)
                .buttonStyle(QsButtonStyle(priority: .primary))
            Button("Import a library", action: onImport)
                .buttonStyle(QsButtonStyle(priority: .outline))
        }
    }

    // MARK: Data

    private func count(_ s: ReadingStatus) -> Int { books.filter { $0.status == s }.count }

    private var visibleBooks: [Book] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return filter.apply(to: books.filter { $0.status == shelf })
            .filter { q.isEmpty || $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q) }
    }

    private func open(_ book: Book) {
        if duo.mode == .book { selected = book } else { path.append(book) }
    }

    /// Start on the first shelf that has books.
    private func pickInitialShelf() {
        guard !pickedInitialShelf else { return }
        pickedInitialShelf = true
        if count(shelf) == 0, let first = ReadingStatus.shelves.first(where: { count($0) > 0 }) { shelf = first }
    }
}

// MARK: - Tile

/// Figma: Books › Book grid cell. Cover, title, then progress (reading) or ★ rating.
private struct LibraryTile: View {
    let book: Book
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            BookCover(source: .data(book.coverData), title: book.title, width: nil)
            Text(book.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if book.status == .reading, let progress = book.progress, book.currentPage > 0 {
                QsProgressBar(value: progress, size: .s)
            } else if let stars = book.stars ?? book.rating.map(Double.init) {
                Text("★ \(stars.formatted())")
                    .font(.caption)
                    .foregroundStyle(theme.palette.ink2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(book.title), \(book.author)"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Empty shelf (Flow 7 › Empty shelf)

private struct EmptyShelf: View {
    let shelf: ReadingStatus
    @Environment(\.theme) private var theme

    private var message: LocalizedStringKey {
        switch shelf {
        case .reading: "Books you’re reading show up here. Pick one from Want to read when you’re ready."
        case .toRead: "Books you’d like to read one day land here."
        case .read: "Finished books gather here, one by one."
        case .stopped: "Books you stop reading land here. No judgement, just a quiet shelf."
        }
    }

    var body: some View {
        VStack(spacing: Space.s12) {
            // Three soft book spines.
            HStack(alignment: .bottom, spacing: 0) {
                RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.soft)
                    .frame(width: 64, height: 96).rotationEffect(.degrees(-7))
                RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.soft2)
                    .frame(width: 64, height: 96)
                RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.soft)
                    .frame(width: 64, height: 96).rotationEffect(.degrees(7))
            }
            .padding(.vertical, Space.s8)
            .accessibilityHidden(true)
            Text("Nothing here, and that’s fine")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.s40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .gentleAppear()
    }
}

// MARK: - Sort & filter

enum LibrarySort: CaseIterable {
    case recent, title, author, rating

    var label: String {
        switch self {
        case .recent: String(localized: "Recently updated")
        case .title: String(localized: "Title")
        case .author: String(localized: "Author")
        case .rating: String(localized: "My rating")
        }
    }
}

enum FinishedIn: CaseIterable, Hashable {
    case thisYear, lastYear, earlier

    var label: String {
        let year = Calendar.current.component(.year, from: .now)
        switch self {
        case .thisYear: return String(year)
        case .lastYear: return String(year - 1)
        case .earlier: return String(localized: "Earlier")
        }
    }

    func contains(_ date: Date?) -> Bool {
        guard let date else { return false }
        let year = Calendar.current.component(.year, from: .now)
        let y = Calendar.current.component(.year, from: date)
        switch self {
        case .thisYear: return y == year
        case .lastYear: return y == year - 1
        case .earlier: return y < year - 1
        }
    }
}

struct LibraryFilter: Equatable {
    var sort: LibrarySort = .recent
    var moods: Set<String> = []
    var finishedIn: Set<FinishedIn> = []

    func apply(to books: [Book]) -> [Book] {
        books
            .filter { moods.isEmpty || !moods.isDisjoint(with: $0.moods) }
            .filter { book in finishedIn.isEmpty || finishedIn.contains { $0.contains(book.dateFinished) } }
            .sorted(by: isOrderedBefore)
    }

    private func isOrderedBefore(_ a: Book, _ b: Book) -> Bool {
        switch sort {
        case .recent: return a.lastUpdated > b.lastUpdated
        case .title: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .author: return a.author.localizedCaseInsensitiveCompare(b.author) == .orderedAscending
        case .rating: return Self.rating(a) > Self.rating(b)
        }
    }

    private static func rating(_ book: Book) -> Double {
        if let stars = book.stars { return stars }
        return Double(book.rating ?? 0)
    }
}

/// Flow 7 › Sort & filter sheet. Changes apply with "Show N books".
private struct SortFilterSheet: View {
    @Binding var filter: LibraryFilter
    let books: [Book]
    let shelf: ReadingStatus
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LibraryFilter()

    private var moodOptions: [String] {
        let used = Set(books.flatMap(\.moods))
        let base = ["Cozy", "Slow", "Hopeful", "Dark", "Funny"]
        return base + used.subtracting(base).sorted()
    }

    private var resultCount: Int { draft.apply(to: books.filter { $0.status == shelf }).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("Sort & filter")
                    .font(theme.headline(24, relativeTo: .title2))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                section("Sort by") {
                    ForEach(LibrarySort.allCases, id: \.self) { s in
                        QsChip(title: s.label, isSelected: draft.sort == s) { draft.sort = s }
                    }
                }
                section("Mood") {
                    ForEach(moodOptions, id: \.self) { mood in
                        QsChip(title: String(localized: String.LocalizationValue(mood)), isSelected: draft.moods.contains(mood)) {
                            if draft.moods.contains(mood) { draft.moods.remove(mood) } else { draft.moods.insert(mood) }
                        }
                    }
                }
                section("Finished in") {
                    ForEach(FinishedIn.allCases, id: \.self) { f in
                        QsChip(title: f.label, isSelected: draft.finishedIn.contains(f)) {
                            if draft.finishedIn.contains(f) { draft.finishedIn.remove(f) } else { draft.finishedIn.insert(f) }
                        }
                    }
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(resultCount == 1 ? "Show 1 book" : "Show \(resultCount) books") {
                filter = draft
                dismiss()
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.surface)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear { draft = filter }
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder chips: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(title)
                .textCase(.uppercase)
                .font(.caption.weight(.semibold))
                .tracking(0.72)
                .foregroundStyle(theme.palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Space.s8) { chips() }
        }
    }
}
