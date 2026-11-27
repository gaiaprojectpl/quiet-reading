import SwiftUI
import SwiftData

/// Flow 1 › Step 5 · Home: today's date, the book being read now, and what's up next.
struct HomeView: View {
    var onSeeAll: () -> Void = {}
    var onAddBook: () -> Void = {}
    @Environment(\.theme) private var theme
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]
    @State private var updating: Book?

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
                Button("Add a book", action: onAddBook)
                    .buttonStyle(QsButtonStyle(kind: .primary))
            }
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s20) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(0.72)
                            .foregroundStyle(theme.palette.ink2)
                        Text("Reading now")
                            .font(theme.headline(32, relativeTo: .largeTitle))
                            .foregroundStyle(theme.palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        if let current {
                            CurrentBookCard(book: current, onUpdate: { updating = current })
                        } else {
                            InfoBanner(message: "No book in progress. Pick one from Up next or your library.")
                        }
                        if !upNext.isEmpty {
                            upNextSection
                        }
                    }
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s16)
                    .padding(.bottom, Space.s40)
                }
                .background(theme.palette.bg.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
            .sheet(item: $updating) { book in
                UpdatePageSheet(book: book)
            }
        }
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: Space.s20) {
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.s16) {
                    ForEach(upNext) { book in
                        VStack(alignment: .leading, spacing: Space.s8) {
                            BookCover(source: .data(book.coverData), title: book.title, width: 100)
                            Text(book.title)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(theme.palette.ink)
                                .lineLimit(2)
                                .frame(width: 100, alignment: .leading)
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
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

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
        .padding(Space.s16)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .strokeBorder(theme.palette.line, lineWidth: 0.75))
    }
}

/// Typed progress (number keyboard opens straight away). Flow 3 will replace this with the full design.
private struct UpdatePageSheet: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var page: Int?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text(book.title)
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
            VStack(alignment: .leading, spacing: Space.s8) {
                Text("Page you’re on")
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.ink2)
                TextField("Page", value: $page, format: .number)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .font(.body)
                    .padding(.horizontal, Space.s12)
                    .frame(minHeight: Size.field)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                        .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
            }
            Button("Save") {
                if let page {
                    book.currentPage = max(0, book.pageCount.map { min(page, $0) } ?? page)
                    book.lastUpdated = .now
                    try? context.save()
                }
                dismiss()
            }
            .buttonStyle(QsButtonStyle(kind: .primary))
            Spacer()
        }
        .padding(Space.s20)
        .background(theme.palette.bg.ignoresSafeArea())
        .presentationDetents([.medium])
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
