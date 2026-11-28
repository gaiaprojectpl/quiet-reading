import SwiftUI
import SwiftData

/// Flow 3 › Step 4 · Finished moment → Step 5 · What's next. Shown full screen over Home.
struct FinishFlow: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showNext = false

    var body: some View {
        NavigationStack {
            FinishedView(book: book) { hasNext in
                if hasNext { showNext = true } else { dismiss() }
            }
            .navigationDestination(isPresented: $showNext) {
                WhatNextView(onDone: { dismiss() })
            }
        }
        .tint(theme.palette.accentInk)
    }
}

// MARK: - Finished moment

struct FinishedView: View {
    let book: Book
    /// Called after Save / Skip with whether there is something on the Want to read shelf.
    let onDone: (Bool) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Book> { $0.statusRaw == "toRead" }) private var wantToRead: [Book]

    @State private var stars: Double?
    @State private var moods: Set<String> = []

    var body: some View {
        Group {
            if duo.mode == .book {
                HStack(spacing: duo.fold.width) {
                    ScrollView { celebration.gentleAppear().padding(Space.s20) }
                        .frame(width: duo.fold.minX)
                    ScrollView { feelings.gentleAppear(delay: Motion.fast).padding(Space.s20) }
                        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
                }
            } else {
                ScrollView {
                    VStack(spacing: Space.s16) {
                        celebration.gentleAppear()
                        feelings.gentleAppear(delay: Motion.fast)
                    }
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s24)
                    .padding(.bottom, Space.s24)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            }
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            stars = book.stars
            moods = Set(book.moods)
        }
    }

    private var celebration: some View {
        VStack(spacing: Space.s16) {
            BookCover(source: .data(book.coverData), title: book.title, width: 150)
            Text(String(localized: "Finished · \(Date.now.formatted(.dateTime.day().month(.wide)))").uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.72)
                .foregroundStyle(theme.palette.ink2)
            Text("You finished \(book.title)")
                .font(theme.headline(28, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    private var feelings: some View {
        FeelingsEditor(stars: $stars, moods: $moods, extra: book.moods)
    }

    private var actions: some View {
        VStack(spacing: Space.s12) {
            Button("Save") { complete(saveFeelings: true) }
                .buttonStyle(QsButtonStyle(priority: .primary))
            Button("Skip for now") { complete(saveFeelings: false) }
                .buttonStyle(QsButtonStyle(priority: .text))
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s12)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .background(theme.palette.bg)
    }

    private func complete(saveFeelings: Bool) {
        let previous = book.currentPage
        if let pages = book.pageCount, pages > previous {
            let session = ReadingSession(fromPage: previous, toPage: pages)
            session.book = book
            context.insert(session)
            book.currentPage = pages
        }
        book.status = .read
        book.dateFinished = .now
        book.lastUpdated = .now
        if saveFeelings {
            book.stars = stars
            book.moods = (Feelings.suggested + Feelings.custom + book.moods).filter(moods.contains).uniqued()
        }
        try? context.save()
        onDone(!wantToRead.filter { $0.persistentModelID != book.persistentModelID }.isEmpty)
    }
}

// MARK: - What's next

struct WhatNextView: View {
    let onDone: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Book> { $0.statusRaw == "toRead" }, sort: \Book.dateAdded)
    private var wantToRead: [Book]

    var body: some View {
        Group {
            if duo.mode == .book {
                HStack(spacing: duo.fold.width) {
                    page.frame(width: duo.fold.minX)
                    DuoIllustrationPage()
                }
            } else {
                page
            }
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                Text("What’s next?")
                    .font(theme.headline(30, relativeTo: .title))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("From your Want to read shelf")
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.ink2)
                QsListCard {
                    ForEach(wantToRead.prefix(5)) { book in
                        Button { start(book) } label: {
                            HStack(spacing: Space.s16) {
                                BookCover(source: .data(book.coverData), title: book.title, width: 52)
                                VStack(alignment: .leading, spacing: Space.s2) {
                                    Text(book.title)
                                        .font(theme.headline(18, relativeTo: .body))
                                        .foregroundStyle(theme.palette.ink)
                                    Text(book.pageCount.map { "\(book.author) · \($0) pages" } ?? book.author)
                                        .font(.footnote)
                                        .foregroundStyle(theme.palette.ink2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(Space.s12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Start reading")
                    }
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Choose later", action: onDone)
                .buttonStyle(QsButtonStyle(priority: .secondary))
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s12)
                .padding(.bottom, QsLayout.actionsAboveBottomLine)
                .background(theme.palette.bg)
        }
    }

    private func start(_ book: Book) {
        book.status = .reading
        book.lastUpdated = .now
        try? context.save()
        onDone()
    }
}

extension Array where Element == String {
    /// Keeps the first of each value, in order.
    func uniqued() -> [String] { var seen = Set<String>(); return filter { seen.insert($0).inserted } }
}
