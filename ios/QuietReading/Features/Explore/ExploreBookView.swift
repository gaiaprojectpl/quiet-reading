import SwiftUI
import SwiftData

/// Flow 12 › 4 · Book preview and › 5 · Added to Want to read.
/// Adding never starts a book: it goes to Want to read unless the reader says they're reading it.
struct ExploreBookView: View {
    let book: ExploreBook
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(\.duoLayout) private var duo
    @Environment(CompanionStore.self) private var companion
    @Query private var shelf: [Book]
    @State private var about: String?
    @State private var aboutLoaded = false
    @State private var expanded = false
    @State private var openShelfBook: Book?

    /// The same book already on the reader's shelf (title + author, or ISBN).
    private var onShelf: Book? {
        let key = ExploreAdder.key(title: book.title, author: book.author)
        return shelf.first { ExploreAdder.key(title: $0.title, author: $0.author) == key || ($0.isbn != nil && $0.isbn == book.isbn) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s12) {
                ExploreCover(book: book, width: Size.coverL - Space.s16, large: true)
                    .padding(.bottom, Space.s8)
                Text(book.title)
                    .font(theme.headline(28, relativeTo: .title))
                    .foregroundStyle(theme.palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if !book.author.isEmpty {
                    Text(book.author).font(.body).foregroundStyle(theme.palette.ink2)
                }
                if let rating = book.rating, let n = book.ratingsCount, n > 0 { ratingRow(rating, n) }
                facts
                aboutSection
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack { QsBackButton(title: "Explore"); Spacer() }
                .padding(.horizontal, Space.s12)
                .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { companion.buttonHidden = true }
        .onDisappear { companion.buttonHidden = false }
        .task {
            about = await ExploreCatalog.description(for: book)
            aboutLoaded = true
        }
        .navigationDestination(item: $openShelfBook) { BookDetailView(book: $0) }
    }

    private func ratingRow(_ rating: Double, _ count: Int) -> some View {
        HStack(spacing: Space.s8) {
            HStack(spacing: Space.s2) {
                ForEach(1...5, id: \.self) { i in
                    Image(rating >= Double(i) - 0.25 ? "qs.star-fill" : rating >= Double(i) - 0.75 ? "qs.star-half" : "qs.star-empty")
                        .resizable().frame(width: Size.iconM - 2, height: Size.iconM - 2)
                        .foregroundStyle(theme.palette.accent)
                }
            }
            Text("\(rating.formatted(.number.precision(.fractionLength(1)))) · \(count.formatted(.number.notation(.compactName))) ratings on Open Library")
                .font(.footnote).foregroundStyle(theme.palette.ink2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 5 by \(count) readers on Open Library"))
    }

    /// Genre · pages · year, as quiet tags: one centred row, or two when they don't fit.
    private var facts: some View {
        let tags = book.genres.map(\.title) + [book.pages.map { String(localized: "\($0) pages") }, book.year.map(String.init)].compactMap { $0 }
        let split = (tags.count + 1) / 2
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s8) { ForEach(tags, id: \.self, content: tag) }
            VStack(spacing: Space.s8) {
                HStack(spacing: Space.s8) { ForEach(Array(tags.prefix(split)), id: \.self, content: tag) }
                HStack(spacing: Space.s8) { ForEach(Array(tags.dropFirst(split)), id: \.self, content: tag) }
            }
        }
        .padding(.top, Space.s4)
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(theme.palette.ink)
            .lineLimit(1)
            .padding(.horizontal, Space.s12).padding(.vertical, Space.s6)
            .overlay(Capsule().strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }

    @ViewBuilder private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            if let about {
                Text(about)
                    .font(.subheadline).foregroundStyle(theme.palette.ink)
                    .lineLimit(expanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !expanded && about.count > 220 {
                    Button("More") { withAnimation(.easeOut(duration: Motion.base)) { expanded = true } }
                        .font(.subheadline.weight(.medium)).foregroundStyle(theme.palette.accentInk)
                        .frame(minHeight: Size.touchIos)
                }
            } else if aboutLoaded {
                Text("No description yet. Open Library is a shared catalogue, so details fill in over time.")
                    .font(.subheadline).foregroundStyle(theme.palette.ink2)
            } else {
                VStack(alignment: .leading, spacing: Space.s8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(theme.palette.disabledBg).frame(maxWidth: i == 2 ? 180 : .infinity).frame(height: Space.s12)
                    }
                }
                .accessibilityLabel("Loading the description")
            }
        }
        .padding(.top, Space.s12)
    }

    /// Pinned 24 pt above the bottom line (tab bar).
    private var actions: some View {
        VStack(spacing: Space.s12) {
            if let mine = onShelf {
                Button(mine.status == .toRead ? "In Want to read" : String(localized: "On your shelf · \(mine.status.bookLabel)")) {
                    openShelfBook = mine
                }
                .buttonStyle(QsButtonStyle(priority: .outline))
                .accessibilityHint("Opens the book on your shelf")
                if mine.status == .toRead {
                    Button("I’m reading it") { ExploreAdder.startReading(mine, context: context, notifications: notifications) }
                        .buttonStyle(QsButtonStyle(priority: .outline))
                }
            } else {
                Button("Add to Want to read") { ExploreAdder.add(book, status: .toRead, context: context, notifications: notifications) }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                Button("I’m reading it") { ExploreAdder.add(book, status: .reading, context: context, notifications: notifications) }
                    .buttonStyle(QsButtonStyle(priority: .outline))
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s12)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .background(theme.palette.bg)
        .gentleAnimation(onShelf?.statusRaw)
    }
}

/// Puts an Explore book on the shelf (saved straight away; the cover downloads in the background).
enum ExploreAdder {
    static func key(title: String, author: String) -> String {
        let t = title.lowercased().filter { $0.isLetter || $0.isNumber }
        let a = (author.components(separatedBy: ",").first ?? author).lowercased().filter { $0.isLetter }
        return "\(t)|\(a)"
    }

    static func add(_ b: ExploreBook, status: ReadingStatus, context: ModelContext, notifications: NotificationCenterModel) {
        let book = Book(title: b.title, author: b.author, isbn: b.isbn, pageCount: b.pages, status: status, source: .manual)
        context.insert(book)
        try? context.save()
        let title = status == .reading ? String(localized: "Added to Reading now") : String(localized: "Added to Want to read")
        let where_ = status == .reading ? String(localized: "It’s on Home now.") : String(localized: "Find it in Library › Want to read.")
        notifications.show(title, message: where_, actionTitle: String(localized: "Undo")) {
            context.delete(book)
            try? context.save()
        }
        Task {
            if let data = await BookSearch.coverData(isbn: b.isbn, fallbackURL: b.largeCoverURL) {
                book.coverData = data
                try? context.save()
            }
        }
    }

    static func startReading(_ book: Book, context: ModelContext, notifications: NotificationCenterModel) {
        book.status = .reading
        book.lastUpdated = .now
        try? context.save()
        notifications.show(String(localized: "Moved to Reading now"), message: String(localized: "It’s on Home now."),
                           actionTitle: String(localized: "Undo")) {
            book.status = .toRead
            try? context.save()
        }
    }
}
