import SwiftUI
import SwiftData

/// Flow 12 · Explore (Figma 268:13166): find books you don't know yet.
/// Browse (genre chips, "… you might like", Authors to discover) → search or filter → results → book preview.
/// Everything is real: Open Library search, filters and covers (see `ExploreCatalog`).
struct ExploreView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Connectivity.self) private var connectivity
    @Query private var shelf: [Book]

    @State private var text = ""
    @State private var filters = ExploreFilters()
    @State private var sort: ExploreSort = .bestMatch
    /// "See all" on a browse shelf shows results without typing.
    @State private var showAll = false
    @State private var showFilters = false
    @State private var path: [ExploreBook] = []
    @FocusState private var searchFocused: Bool

    // Browse
    @State private var featured: [ExploreBook] = []
    @State private var browseState: LoadState = .loading
    // Results
    @State private var results: [ExploreBook] = []
    @State private var total = 0
    @State private var page = 1
    @State private var resultsState: LoadState = .idle
    @State private var loadingMore = false

    enum LoadState: Equatable { case idle, loading, slow, loaded, offline, failed }

    private var isBrowsing: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty && filters.isEmpty && !showAll }
    /// Browse shelf genre: Classics by default (Figma), or the reader's most-read genre later.
    private let browseGenre: ExploreGenre = .classics
    private var shelfKeys: Set<String> { Set(shelf.map { ExploreAdder.key(title: $0.title, author: $0.author) }) }
    private var searchKey: String { "\(text)|\(filters)|\(sort)|\(showAll)" }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    ScreenTitle(title: "Explore")
                    searchRow
                    chipRow
                    if isBrowsing { browse } else { resultsList }
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreBook.self) { ExploreBookView(book: $0) }
            .sheet(isPresented: $showFilters) {
                ExploreFiltersSheet(filters: $filters, text: text)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task { await loadBrowse() }
            #if DEBUG
            // Test builds: -qsExploreSearch "dragons", -qsExploreFilters "classics,romance,under300",
            // -qsExploreFiltersSheet YES, -qsExploreOpenFirst YES (opens the first result's preview).
            .task {
                let d = UserDefaults.standard
                if let q = d.string(forKey: "qsExploreSearch") { text = q }
                if let f = d.string(forKey: "qsExploreFilters") {
                    for part in f.split(separator: ",").map(String.init) {
                        if let g = ExploreGenre(rawValue: part) { filters.genres.insert(g) }
                        if part == "under300" { filters.length = .under300 }
                        if part == "before1900" { filters.published = .before1900 }
                    }
                }
                if d.bool(forKey: "qsExploreFiltersSheet") { showFilters = true }
                if d.bool(forKey: "qsExploreOpenFirst") {
                    for _ in 0..<40 where results.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
                    if let first = results.first ?? featured.first { path = [first] }
                }
            }
            #endif
            .task(id: searchKey) { await loadResults() }
            .gentleAnimation(isBrowsing)
        }
    }

    // MARK: Header

    private var searchRow: some View {
        HStack(spacing: Space.s8) {
            QsSearchField(prompt: "Title, author or ISBN", text: $text, focus: $searchFocused)
            Button { showFilters = true } label: {
                Image("qs.filter").resizable()
                    .frame(width: Size.iconL, height: Size.iconL)
                    .foregroundStyle(theme.palette.ink)
                    .frame(width: Size.touchIos, height: Size.touchIos)
                    .background(filters.isEmpty ? theme.palette.surface : theme.palette.soft, in: Circle())
                    .overlay(Circle().strokeBorder(filters.isEmpty ? theme.palette.lineStrong : theme.palette.tintStrong, lineWidth: Size.stroke))
                    .contentShape(Circle())
            }
            .buttonStyle(QsPressStyle())
            .accessibilityLabel("Filters")
            .accessibilityValue(filters.isEmpty ? Text("None") : Text("\(filters.count) on"))
        }
    }

    /// Browse: pick a genre. Results: the filters that are on, each removable.
    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s8) {
                if isBrowsing || filters.isEmpty {
                    QsChip(title: String(localized: "All"), isSelected: filters.genres.isEmpty) { filters.genres = [] }
                    ForEach(ExploreGenre.allCases) { g in
                        QsChip(title: g.title, isSelected: filters.genres.contains(g)) { filters.genres = [g] }
                    }
                } else {
                    ForEach(activeFilterChips, id: \.title) { chip in
                        RemovableChip(title: chip.title, action: chip.remove)
                    }
                }
            }
        }
        .contentMargins(.horizontal, Space.s20, for: .scrollContent)
        .padding(.horizontal, -Space.s20)
        .clipped()
    }

    private var activeFilterChips: [(title: String, remove: () -> Void)] {
        var chips: [(String, () -> Void)] = filters.genres.sorted { $0.rawValue < $1.rawValue }.map { g in (g.title, { filters.genres.remove(g) }) }
        switch filters.length {
        case .any: break
        case .under300: chips.append((String(localized: "Under 300 pages"), { filters.length = .any }))
        case .over300: chips.append((String(localized: "300+ pages"), { filters.length = .any }))
        }
        switch filters.published {
        case .any: break
        case .before1900: chips.append((String(localized: "Before 1900"), { filters.published = .any }))
        case .from1900: chips.append((String(localized: "1900–1999"), { filters.published = .any }))
        case .since2000: chips.append((String(localized: "2000 and later"), { filters.published = .any }))
        }
        if let a = filters.author { chips.append((a, { filters.author = nil })) }
        if filters.language == .any { chips.append((String(localized: "All languages"), { filters.language = .english })) }
        return chips
    }

    // MARK: Browse

    @ViewBuilder private var browse: some View {
        sectionHeader(String(localized: "\(browseGenre.title) you might like")) {
            filters.genres = [browseGenre]
        }
        switch browseState {
        case .loading, .idle, .slow:
            HStack(spacing: Space.s16) { ForEach(0..<4, id: \.self) { _ in CoverSkeleton(width: Self.tile) } }
                .frame(maxWidth: .infinity, alignment: .leading).clipped()
                .accessibilityLabel("Loading books")
        case .offline:
            InfoBanner(message: "Explore needs a connection. Your own books are all here.")
        case .failed:
            retry { Task { await loadBrowse() } }
        case .loaded:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Space.s16) {
                    ForEach(featured) { b in
                        NavigationLink(value: b) { CoverTile(book: b, width: Self.tile) }
                            .buttonStyle(QsPressStyle())
                    }
                }
            }
            .contentMargins(.horizontal, Space.s20, for: .scrollContent)
            .padding(.horizontal, -Space.s20)

            if !authors.isEmpty {
                sectionHeader(String(localized: "Authors to discover")) {
                    filters.genres = [browseGenre]
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.s12) {
                        ForEach(Array(authors.enumerated()), id: \.element) { i, name in
                            Button { filters.author = name } label: { AuthorBubble(name: name, index: i) }
                                .buttonStyle(QsPressStyle())
                                .accessibilityHint("Shows their books")
                        }
                    }
                }
                .contentMargins(.horizontal, Space.s20, for: .scrollContent)
                .padding(.horizontal, -Space.s20)
            }
        }
    }

    /// Authors of the featured books, first ones not already on the reader's shelf.
    private var authors: [String] {
        let mine = Set(shelf.map { $0.author.lowercased() })
        var seen: [String] = []
        for b in featured {
            let a = b.author.components(separatedBy: ", ").first ?? b.author
            if !a.isEmpty, !seen.contains(a), !mine.contains(a.lowercased()) { seen.append(a) }
        }
        return Array(seen.prefix(8))
    }

    private func sectionHeader(_ title: String, seeAll: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(theme.headline(20, relativeTo: .title3)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("See all", action: seeAll)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.palette.accentInk)
                .frame(minHeight: Size.touchIos)
        }
        .padding(.top, Space.s16)
    }

    private func loadBrowse() async {
        guard featured.isEmpty else { return }
        browseState = .loading
        do {
            let page = try await ExploreCatalog.search(text: "", filters: ExploreFilters(genres: [browseGenre]), sort: .mostRead, limit: 24)
            let keys = shelfKeys
            featured = page.books.filter { !keys.contains(ExploreAdder.key(title: $0.title, author: $0.author)) }.prefix(12).map { $0 }
            browseState = .loaded
        } catch ExploreError.offline {
            browseState = .offline
        } catch {
            browseState = .failed
        }
    }

    // MARK: Results

    @ViewBuilder private var resultsList: some View {
        switch resultsState {
        case .idle, .loading, .slow:
            VStack(alignment: .leading, spacing: Space.s12) {
                if resultsState == .slow {
                    InfoBanner(message: "This is taking longer than usual. Open Library can be slow at busy times.")
                }
                ForEach(0..<5, id: \.self) { _ in RowSkeleton() }
            }
            .accessibilityLabel("Searching")
        case .offline:
            EmptyStateView(icon: "qs.cloudoff", title: "Explore needs a connection",
                           message: "Your own books are all here. Try again when you’re back online.")
            retry { Task { await loadResults() } }
        case .failed:
            EmptyStateView(icon: "qs.alert", title: "The catalogue isn’t answering",
                           message: "Nothing is lost. Try again in a moment.")
            retry { Task { await loadResults() } }
        case .loaded where results.isEmpty:
            noResults
        case .loaded:
            HStack {
                Text(total == 1 ? String(localized: "1 book") : String(localized: "\(total.formatted()) books"))
                    .font(.subheadline.weight(.medium)).foregroundStyle(theme.palette.ink)
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(ExploreSort.allCases.filter { $0 != .bestMatch || !text.isEmpty }, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack(spacing: Space.s4) {
                        Text(sort == .bestMatch && text.isEmpty ? ExploreSort.mostRead.title : sort.title)
                        Image("qs.sort").resizable().frame(width: Size.iconM, height: Size.iconM).accessibilityHidden(true)
                    }
                    .font(.subheadline).foregroundStyle(theme.palette.ink)
                    .frame(minHeight: Size.touchIos)
                }
                .accessibilityLabel("Sort: \(sort.title)")
            }
            LazyVStack(spacing: 0) {
                ForEach(results) { b in
                    NavigationLink(value: b) { ResultRow(book: b, onShelf: shelfKeys.contains(ExploreAdder.key(title: b.title, author: b.author))) }
                        .buttonStyle(.plain)
                        .onAppear { if b.id == results.last?.id { Task { await loadMore() } } }
                }
                if loadingMore { ProgressView().padding(Space.s16) }
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: Space.s16) {
            let n = filters.count
            EmptyStateView(
                icon: "qs.search",
                title: n > 2 ? "No books match all \(n) filters" : n == 2 ? "No books match both filters" : (text.isEmpty ? "No books match this filter" : "No books found for “\(text)”"),
                message: n > 0 ? "Try fewer filters, or search in all genres." : "Check the spelling, or try the author’s name.")
            if n > 0 {
                Button("Clear filters") { filters = ExploreFilters() }
                    .buttonStyle(QsButtonStyle(priority: .outline, size: .small))
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .gentleAppear()
    }

    private func retry(_ action: @escaping () -> Void) -> some View {
        Button("Try again", action: action)
            .buttonStyle(QsButtonStyle(priority: .outline, size: .small))
            .fixedSize()
            .frame(maxWidth: .infinity)
    }

    private func loadResults() async {
        guard !isBrowsing else { resultsState = .idle; return }
        // Wait for the reader to stop typing.
        if !text.isEmpty { try? await Task.sleep(for: .milliseconds(400)) }
        guard !Task.isCancelled else { return }
        resultsState = .loading
        let slow = Task { try? await Task.sleep(for: .seconds(8)); if !Task.isCancelled, resultsState == .loading { resultsState = .slow } }
        defer { slow.cancel() }
        do {
            let p = try await ExploreCatalog.search(text: text, filters: filters, sort: sort)
            guard !Task.isCancelled else { return }
            results = p.books; total = p.total; page = 1
            resultsState = .loaded
        } catch is CancellationError {
        } catch ExploreError.offline {
            resultsState = .offline
        } catch {
            if !Task.isCancelled { resultsState = connectivity.isOnline ? .failed : .offline }
        }
    }

    private func loadMore() async {
        guard !loadingMore, results.count < total else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let p = try? await ExploreCatalog.search(text: text, filters: filters, sort: sort, page: page + 1) {
            let known = Set(results.map(\.id))
            results += p.books.filter { !known.contains($0.id) }
            page += 1
        }
    }

    private static let tile: CGFloat = Size.coverM + Space.s24
}

// MARK: - Pieces

/// Cover from the catalogue, or a generated cover (title and author on soft2, Figma › Book cover).
struct ExploreCover: View {
    let book: ExploreBook
    let width: CGFloat
    var large = false
    @Environment(\.theme) private var theme

    var body: some View {
        AsyncImage(url: large ? book.largeCoverURL : book.coverURL, transaction: Transaction(animation: .easeOut(duration: Motion.base))) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                GeneratedCover(title: book.title, author: book.author, width: width)
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 3)
        .accessibilityHidden(true)
    }
}

/// 🧱 Components › Book cover, generated: accent rule, title in the heading font, author.
struct GeneratedCover: View {
    let title: String
    let author: String
    let width: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: width * 0.04) {
            theme.palette.accent.frame(width: width * 0.3, height: max(1, width * 0.016))
            Text(title).font(.custom(theme.headFont.family, size: width * 0.14).weight(theme.headFont.weight))
                .foregroundStyle(theme.palette.ink).multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.7)
            if width >= Size.coverM {
                Text(author).font(.system(size: width * 0.08)).foregroundStyle(theme.palette.ink2).lineLimit(1)
            }
        }
        .padding(.horizontal, width * 0.08)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.soft2)
    }
}

private struct CoverTile: View {
    let book: ExploreBook
    let width: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            ExploreCover(book: book, width: width)
            Text(book.title).font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink).lineLimit(2)
            Text(book.author).font(.caption).foregroundStyle(theme.palette.ink2).lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(book.title) by \(book.author)"))
        .accessibilityAddTraits(.isButton)
    }
}

private struct ResultRow: View {
    let book: ExploreBook
    let onShelf: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.s16) {
            ExploreCover(book: book, width: Size.coverS - Space.s8)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(book.title).font(theme.headline(17, relativeTo: .headline)).foregroundStyle(theme.palette.ink).lineLimit(2)
                Text(book.detailLine).font(.footnote).foregroundStyle(theme.palette.ink2).lineLimit(2)
                if onShelf {
                    Text("On your shelf").font(.caption.weight(.medium)).foregroundStyle(theme.palette.accentInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("qs.chevron").resizable().frame(width: Size.iconS + 2, height: Size.iconS + 2)
                .foregroundStyle(theme.palette.ink2).accessibilityHidden(true)
        }
        .padding(.vertical, Space.s12)
        .frame(minHeight: Size.touchIos)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct AuthorBubble: View {
    let name: String
    let index: Int
    @Environment(\.theme) private var theme

    /// "Jane Austen" → "JA", "Louisa May Alcott" → "LA".
    private var initials: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        guard let first = words.first?.first else { return "" }
        guard words.count > 1, let last = words.last?.first else { return String(first) }
        return String(first) + String(last)
    }

    var body: some View {
        let p = theme.palette
        let fills = [p.soft, p.soft2, p.infoSoft, p.warningSoft, p.successSoft]
        VStack(spacing: Space.s6) {
            Text(initials)
                .font(theme.headline(20, relativeTo: .title3)).foregroundStyle(p.ink)
                .frame(width: Space.s64, height: Space.s64)
                .background(fills[index % fills.count], in: Circle())
            Text(name).font(.caption).foregroundStyle(p.ink).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(width: Space.s64 + Space.s12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(.isButton)
    }
}

/// An active filter: tap × (or the chip) to remove it.
private struct RemovableChip: View {
    let title: String
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s6) {
                Image("qs.check").resizable().frame(width: Size.iconS, height: Size.iconS).foregroundStyle(theme.palette.accentInk)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(theme.palette.ink)
                Image("qs.close").resizable().frame(width: Size.iconS - 4, height: Size.iconS - 4).foregroundStyle(theme.palette.ink)
            }
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s6)
            .frame(minHeight: Size.buttonSmall - Space.s8)
            .background(theme.palette.soft2, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.palette.accent, lineWidth: 1.5))
            .frame(minHeight: Size.touchIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(QsPressStyle())
        .accessibilityLabel(Text(title))
        .accessibilityHint("Removes this filter")
    }
}

private struct CoverSkeleton: View {
    let width: CGFloat
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.disabledBg).frame(width: width, height: width * 1.5)
            Capsule().fill(theme.palette.disabledBg).frame(width: width * 0.8, height: Space.s12)
            Capsule().fill(theme.palette.disabledBg).frame(width: width * 0.6, height: Space.s8)
        }
    }
}

private struct RowSkeleton: View {
    @Environment(\.theme) private var theme
    var body: some View {
        HStack(spacing: Space.s16) {
            RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.disabledBg).frame(width: Size.coverS - Space.s8, height: (Size.coverS - Space.s8) * 1.5)
            VStack(alignment: .leading, spacing: Space.s8) {
                Capsule().fill(theme.palette.disabledBg).frame(width: 160, height: Space.s12)
                Capsule().fill(theme.palette.disabledBg).frame(width: 220, height: Space.s8)
            }
            Spacer()
        }
        .accessibilityHidden(true)
    }
}
