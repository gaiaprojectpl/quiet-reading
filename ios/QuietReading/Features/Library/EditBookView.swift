import SwiftUI
import SwiftData

/// Book details › More › Edit details: fix a typo, the language or page count, or pick a nicer cover
/// from the catalogue (covers of this book's editions from Google Books and Open Library).
struct EditBookView: View {
    @Bindable var book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @State private var title = ""
    @State private var author = ""
    @State private var pages = ""
    @State private var language = "English"
    @State private var newCover: Data?
    @State private var covers: [BookCandidate] = []
    @State private var loadingCovers = true
    @State private var confirmDiscard = false

    private var hasChanges: Bool {
        title != book.title || author != book.author || pages != (book.pageCount.map(String.init) ?? "")
            || language != (book.language ?? "English") || newCover != nil
    }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                QsBackButton(title: "Cancel") { if hasChanges { confirmDiscard = true } else { dismiss() } }
                Spacer()
                Text("Edit details").font(.body.weight(.semibold)).foregroundStyle(theme.palette.ink)
                Spacer()
                Button("Done", action: save)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? theme.palette.accentInk : theme.palette.disabledInk)
                    .disabled(!canSave)
                    .frame(minWidth: Size.touchIos, minHeight: Size.touchIos)
                    .padding(.trailing, Space.s8)
            }
            .padding(.horizontal, Space.s8)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s20) {
                    coverSection
                    QsTextField(label: "Title", text: $title)
                    QsTextField(label: "Author", text: $author, capitalization: .words)
                    QsMenuField(label: "Language", options: BookLanguage.options(), selection: $language)
                    QsTextField(label: "Pages", text: $pages, prompt: "For example 320", keyboard: .numberPad)
                }
                .padding(.horizontal, Space.s20)
                .padding(.vertical, Space.s16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .onAppear {
            title = book.title; author = book.author
            pages = book.pageCount.map(String.init) ?? ""
            language = book.language ?? "English"
        }
        .task { await loadCovers() }
    }

    // MARK: Cover

    private var coverSection: some View {
        QsLabeled("Cover") {
            HStack(alignment: .top, spacing: Space.s16) {
                BookCover(source: .data(newCover ?? book.coverData), title: title, width: Size.coverM)
                Text(newCover == nil ? "Pick a cover below, or use “Change cover” in the book’s details for your own photo."
                                     : "New cover chosen. Tap Done to keep it.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            if loadingCovers {
                HStack(spacing: Space.s12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.disabledBg)
                            .frame(width: Size.coverS + Space.s8, height: (Size.coverS + Space.s8) * 1.5)
                    }
                }
                .accessibilityLabel("Looking for covers")
            } else if covers.isEmpty {
                Text("No other covers found for this book.").font(.footnote).foregroundStyle(theme.palette.ink2)
            } else {
                Text("Covers from the catalogue").font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s12) {
                        ForEach(covers) { c in
                            Button { Task { await pick(c) } } label: {
                                RemoteCover(url: c.coverURL, title: c.title, width: Size.coverS + Space.s8)
                            }
                            .buttonStyle(QsPressStyle())
                            .accessibilityLabel(Text("Cover: \(c.detail ?? c.title)"))
                        }
                    }
                }
            }
        }
    }

    private func loadCovers() async {
        let results = await BookSearch.search("\(book.title) \(book.author)")
        let key = book.title.lowercased().filter(\.isLetter).prefix(10)
        covers = Array(results.filter { $0.coverURL != nil && $0.title.lowercased().filter(\.isLetter).hasPrefix(key) }.prefix(8))
        loadingCovers = false
    }

    private func pick(_ c: BookCandidate) async {
        // Prefer the larger Open Library cover by ISBN, fall back to the thumbnail shown.
        if let data = await BookSearch.coverData(isbn: c.isbn, fallbackURL: c.coverURL) { newCover = data }
    }

    private func save() {
        book.title = title.trimmingCharacters(in: .whitespaces)
        book.author = author.trimmingCharacters(in: .whitespaces)
        let n = Int(pages.filter(\.isNumber)) ?? 0
        book.pageCount = n > 0 ? n : nil
        if let p = book.pageCount, book.currentPage > p { book.currentPage = p }
        book.language = language
        if let newCover { book.coverData = newCover }
        book.lastUpdated = .now
        try? context.save()
        notifications.show(String(localized: "Details saved"), message: String(localized: "“\(book.title)” is up to date."))
        dismiss()
    }
}
