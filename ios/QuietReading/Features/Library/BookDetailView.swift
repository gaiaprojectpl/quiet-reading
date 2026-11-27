import SwiftUI
import SwiftData
import PhotosUI

/// Flow 7 › Step 2 · Book details: header with the shelf chip, progress, notes, Started / Moods / Source.
struct BookDetailView: View {
    let book: Book
    /// False on the open Duo, where details sit on the right page next to the Library.
    var showsBack = true
    var onRemoved: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications

    @State private var updating: Book?
    @State private var finishing: Book?
    @State private var finishAfterSheet: Book?
    @State private var showMove = false
    @State private var removeAfterSheet = false
    @State private var confirmRemove = false
    @State private var editingMoods = false
    @State private var tab: DetailTab = .progress
    @State private var addingQuote = false
    @State private var addingNote = false
    @State private var quoteSource: QuoteSource?
    @State private var pendingQuoteSource: QuoteSource?
    @State private var coverMenu = false
    @State private var takingCover = false
    @State private var pickingCover = false
    @State private var pickedCover: PhotosPickerItem?
    @State private var savingCover = false

    enum DetailTab: Hashable { case progress, quotes, notes }

    private var notes: [ReadingSession] {
        book.sessions.filter { !($0.note ?? "").isEmpty }.sorted { $0.date > $1.date }
    }
    private var quotes: [Quote] { book.quotes.sorted { $0.date > $1.date } }

    /// On the Duo (no bottom tab bar) actions are pinned to the bottom; on iPhone they stay in the card.
    private var pinActions: Bool { duo.mode != .phone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                topBar
                header
                QsSegmented(options: [(DetailTab.progress, String(localized: "Progress")),
                                      (.quotes, String(localized: "Quotes · \(book.quotes.count)")),
                                      (.notes, String(localized: "Notes"))],
                            selection: $tab)
                Group {
                    switch tab {
                    case .progress:
                        progressCard
                        notesCard
                        infoCard
                    case .quotes: quotesTab
                    case .notes: notesTab
                    }
                }
                .transition(.opacity)
                .gentleAnimation(tab)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, Space.s40)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pinActions, tab == .quotes {
                addQuoteButton
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s12)
                    .padding(.bottom, QsLayout.actionsAboveBottomLine)
                    .background(theme.palette.bg)
            } else if pinActions, tab == .notes {
                addNoteButton
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s12)
                    .padding(.bottom, QsLayout.actionsAboveBottomLine)
                    .background(theme.palette.bg)
            } else if pinActions, hasActions {
                actions
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s12)
                    .padding(.bottom, QsLayout.actionsAboveBottomLine)
                    .background(theme.palette.bg)
            }
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $updating, onDismiss: {
            if let b = finishAfterSheet { finishAfterSheet = nil; finishing = b }
        }) { b in
            UpdatePageSheet(book: b, onFinish: { finishAfterSheet = b })
        }
        .fullScreenCover(item: $finishing) { FinishFlow(book: $0).duoCover() }
        .sheet(isPresented: $showMove, onDismiss: {
            if removeAfterSheet { removeAfterSheet = false; confirmRemove = true }
        }) {
            MoveToShelfSheet(book: book, onRemove: { removeAfterSheet = true })
        }
        .sheet(isPresented: $editingMoods) { MoodsSheet(book: book) }
        .sheet(isPresented: $addingQuote, onDismiss: {
            if let s = pendingQuoteSource { pendingQuoteSource = nil; quoteSource = s }
        }) {
            AddQuoteSheet(onChoose: { pendingQuoteSource = $0 })
        }
        .fullScreenCover(item: Binding(get: { quoteSource == .photo ? quoteSource : nil }, set: { quoteSource = $0 })) {
            QuoteFlow(book: book, source: $0).duoCover()
        }
        // Type or write: a modal like Add a note.
        .sheet(item: Binding(get: { quoteSource == .typed ? quoteSource : nil }, set: { quoteSource = $0 })) {
            QuoteFlow(book: book, source: $0)
                .padding(.top, Space.s16)
                .presentationDetents([.large])
                .presentationCornerRadius(theme.radii.sheet)
        }
        .sheet(isPresented: $addingNote) { NoteComposer(book: book) }
        // Cover photo: take one of the book in your hands, or pick one from Photos.
        .confirmationDialog(book.coverData == nil ? "Add a cover" : "Change the cover", isPresented: $coverMenu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take a photo") { takingCover = true } }
            Button("Choose from Photos") { pickingCover = true }
        } message: {
            Text("Hold the book flat and fill the frame. The cover is trimmed for you.")
        }
        .fullScreenCover(isPresented: $takingCover) {
            CameraCapture(front: false) { image in setCover(image) }.ignoresSafeArea()
        }
        .photosPicker(isPresented: $pickingCover, selection: $pickedCover, matching: .images)
        .onChange(of: pickedCover) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { setCover(image) }
                pickedCover = nil
            }
        }
        #if DEBUG
        .task {
            switch UserDefaults.standard.string(forKey: "qsLibrary") {
            case "move": showMove = true
            case "quotes": tab = .quotes
            case "quoteselect", "quotetype": tab = .quotes; quoteSource = UserDefaults.standard.string(forKey: "qsLibrary") == "quotetype" ? .typed : .photo
            default: break
            }
        }
        #endif
        // Flow 7 › Remove a book
        .alert("Remove “\(book.title)”?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: remove)
        } message: {
            Text("Your progress, notes and quotes for this book will be deleted. This can’t be undone.")
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack(spacing: 0) {
            if showsBack { QsBackButton(title: "Library") }
            Spacer()
            ShareLink(item: String(localized: "I’m reading \(book.title) by \(book.author)")) {
                topIcon("qs.share")
            }
            .accessibilityLabel("Share")
            Menu {
                Button("Move to shelf") { showMove = true }
                Button("Remove from library", role: .destructive) { confirmRemove = true }
            } label: {
                topIcon("qs.more")
            }
            .accessibilityLabel("More")
        }
    }

    private func topIcon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .frame(width: Size.iconL, height: Size.iconL)
            .foregroundStyle(theme.palette.ink)
            .frame(width: Size.touchIos, height: Size.touchIos)
            .contentShape(Rectangle())
    }

    /// Saves the reader's own cover photo (trimmed to the book). Saving is silent.
    private func setCover(_ image: UIImage) {
        savingCover = true
        Task {
            let cover = await CoverCropper.crop(image)
            book.coverData = cover.coverJPEG()
            savingCover = false
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Space.s16) {
            VStack(spacing: Space.s4) {
                Button { coverMenu = true } label: {
                    BookCover(source: .data(book.coverData), title: book.title, width: 112)
                        .overlay { if savingCover { ProgressView().tint(theme.palette.ink) } }
                }
                .buttonStyle(QsPressStyle())
                .accessibilityLabel(book.coverData == nil ? "Add a cover photo" : "Change the cover")
                Button(book.coverData == nil ? "Add cover" : "Change cover") { coverMenu = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.palette.accentInk)
                    .frame(minHeight: Size.touchIos)
                    .accessibilityHidden(true)   // same action as the cover above
            }
            .gentleAnimation(book.coverData)
            VStack(alignment: .leading, spacing: Space.s8) {
                Text(book.title)
                    .font(theme.headline(24, relativeTo: .title2))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if !book.author.isEmpty {
                    Text(book.author).font(.subheadline).foregroundStyle(theme.palette.ink2)
                }
                if let pages = book.pageCount {
                    Text("\(pages) pages").font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                QsChip(title: book.status.bookLabel, isSelected: true, icon: book.status.icon) { showMove = true }
                    .accessibilityHint("Move to another shelf")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var progressCard: some View {
        if book.status == .reading {
            card(spacing: Space.s12) {
                if let progress = book.progress, let pages = book.pageCount {
                    QsProgressBar(value: progress)
                    Text(progressLine(pages: pages, progress: progress))
                        .font(.footnote)
                        .foregroundStyle(theme.palette.ink2)
                }
                if !pinActions { actions }
            }
        } else if book.status == .toRead, !pinActions {
            actions
        }
    }

    /// "p. 142 of 310 · 46% · about 3 h 20 min left"
    private func progressLine(pages: Int, progress: Double) -> String {
        var line = book.currentPage == 0
            ? String(localized: "Not started")
            : String(localized: "p. \(book.currentPage) of \(pages) · \(progress.formatted(.percent.precision(.fractionLength(0))))")
        if let left = book.minutesLeft(), left > 0 { line += " · " + ReadingTime.left(left).lowercased() }
        return line
    }

    private var hasActions: Bool { book.status == .reading || book.status == .toRead }

    @ViewBuilder private var actions: some View {
        if book.status == .reading {
            HStack(spacing: Space.s12) {
                Button("Update") { updating = book }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                Button("Finished") { finishing = book }
                    .buttonStyle(QsButtonStyle(priority: .secondary))
            }
        } else if book.status == .toRead {
            Button("Start reading") { move(to: .reading) }
                .buttonStyle(QsButtonStyle(priority: .primary))
        }
    }

    @ViewBuilder private var notesCard: some View {
        if let quote = quotes.first {
            card(spacing: Space.s8) {
                cardHeader(count: quotes.count + notes.count)
                Text("“\(quote.text)”")
                    .font(theme.headline(17, relativeTo: .body))
                    .foregroundStyle(theme.palette.ink)
                    .lineLimit(4)
                Text(quoteMeta(quote)).font(.footnote).foregroundStyle(theme.palette.ink2)
            }
            .onTapGesture { tab = .quotes }
        } else if let latest = notes.first, let text = latest.note {
            card(spacing: Space.s8) {
                HStack(spacing: Space.s8) {
                    Image("qs.quote")
                        .resizable()
                        .frame(width: Size.iconM, height: Size.iconM)
                        .foregroundStyle(theme.palette.accentInk)
                        .accessibilityHidden(true)
                    Text("Notes & quotes · \(notes.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.palette.ink)
                }
                Text("“\(text)”")
                    .font(theme.headline(17, relativeTo: .body))
                    .foregroundStyle(theme.palette.ink)
                Text("p. \(latest.toPage) · \(latest.date.formatted(.dateTime.day().month(.wide)))")
                    .font(.footnote)
                    .foregroundStyle(theme.palette.ink2)
            }
        }
    }

    private func cardHeader(count: Int) -> some View {
        HStack(spacing: Space.s8) {
            Image("qs.quote").resizable().frame(width: Size.iconM, height: Size.iconM)
                .foregroundStyle(theme.palette.accentInk).accessibilityHidden(true)
            Text("Notes & quotes · \(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.palette.ink)
        }
    }

    /// "p. 98 · Cozy" (+ "from a page photo")
    private func quoteMeta(_ q: Quote) -> String {
        var parts: [String] = []
        if let page = q.page { parts.append(String(localized: "p. \(page)")) }
        if let mood = q.mood { parts.append(String(localized: String.LocalizationValue(mood))) }
        if q.fromPhoto { parts.append(String(localized: "from a page photo")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Quotes tab (Flow 9 › Step 1)

    @ViewBuilder private var quotesTab: some View {
        if quotes.isEmpty {
            // Flow 10 › A3 · Quotes · none yet
            EmptyStateView(icon: "qs.quote", title: "No quotes yet",
                           message: "When a line stays with you, save it here with a photo of the page.")
        } else {
            ForEach(quotes) { q in
                let isNew = q.date.timeIntervalSinceNow > -15
                VStack(alignment: .leading, spacing: Space.s8) {
                    HStack(alignment: .top, spacing: Space.s8) {
                        Image("qs.quote").resizable().frame(width: Size.iconS, height: Size.iconS)
                            .foregroundStyle(theme.palette.accentInk).padding(.top, Space.s2).accessibilityHidden(true)
                        if let ink = q.drawing {
                            HandwrittenNoteView(data: ink, label: String(localized: "Handwritten quote: \(q.text)"))
                        } else {
                            Text("“\(q.text)”")
                                .font(theme.headline(15, relativeTo: .body))
                                .foregroundStyle(theme.palette.ink)
                        }
                    }
                    Text([quoteMeta(q), isNew ? String(localized: "new") : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isNew ? theme.palette.soft2 : theme.palette.surface,
                            in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
                .accessibilityElement(children: .combine)
                .contextMenu {
                    Button("Delete quote", role: .destructive) { context.delete(q); try? context.save() }
                }
                .gentleAppear()
            }
        }
        if !pinActions { addQuoteButton }
    }

    private var addQuoteButton: some View {
        Button { addingQuote = true } label: {
            Label { Text("Add a quote") } icon: { Image("qs.quote").resizable().frame(width: Size.iconM, height: Size.iconM) }
        }
        .buttonStyle(QsButtonStyle(priority: .primary))
    }

    // MARK: Notes tab

    @ViewBuilder private var notesTab: some View {
        if notes.isEmpty {
            EmptyStateView(icon: "qs.quote", title: "No notes yet",
                           message: duo.mode != .phone
                               ? "Write a thought with Pencil or type it. Notes stay with this book."
                               : "Jot down a thought about this book. Notes stay with it.")
        } else {
            ForEach(notes) { n in
                VStack(alignment: .leading, spacing: Space.s8) {
                    if let ink = n.noteDrawing {
                        HandwrittenNoteView(data: ink)
                    } else {
                        Text(n.note ?? "").font(.body).foregroundStyle(theme.palette.ink)
                    }
                    Text("p. \(n.toPage) · \(n.date.formatted(.dateTime.day().month(.wide)))" + (n.noteDrawing != nil ? " · " + String(localized: "handwritten") : ""))
                        .font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(n.note ?? ""))
                .accessibilityValue(Text("Page \(n.toPage)"))
                .contextMenu {
                    Button("Delete note", role: .destructive) {
                        if n.fromPage == n.toPage { context.delete(n) } else { n.note = nil; n.noteDrawing = nil }
                        try? context.save()
                    }
                }
                .gentleAppear()
            }
        }
        if !pinActions { addNoteButton }
    }

    private var addNoteButton: some View {
        Button { addingNote = true } label: {
            Label { Text("Add a note") } icon: { Image("qs.pencil").resizable().frame(width: Size.iconM, height: Size.iconM) }
        }
        .buttonStyle(QsButtonStyle(priority: .primary))
    }

    private var infoCard: some View {
        QsListCard {
            QsListRow(icon: "qs.calendar", title: "Started",
                      subtitle: LocalizedStringKey(book.startedDate.formatted(.dateTime.day().month(.wide))))
            if book.status == .read, let finished = book.dateFinished {
                QsListRow(icon: "qs.check", title: "Finished", subtitle: LocalizedStringKey(finishedLine(finished)))
            }
            QsListRow(icon: "qs.tag", title: "Moods",
                      subtitle: LocalizedStringKey(book.moods.isEmpty ? String(localized: "Add how it felt") : book.moods.joined(separator: " · "))) {
                editingMoods = true
            }
            QsListRow(icon: "qs.link", title: "Source", subtitle: LocalizedStringKey(book.sourceLabel))
        }
    }

    private func finishedLine(_ date: Date) -> String {
        var line = date.formatted(.dateTime.day().month(.wide).year())
        if let stars = book.stars ?? book.rating.map(Double.init) { line += " · ★ \(stars.formatted())" }
        return line
    }

    private func card<C: View>(spacing: CGFloat, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: spacing) { content() }
            .padding(Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }

    // MARK: Actions

    private func move(to status: ReadingStatus) {
        let undo = book.move(to: status)
        try? context.save()
        notifications.show(String(localized: "Moved to \(status.shelfName)"),
                           message: String(localized: "You can move it back any time."),
                           kind: .info, actionTitle: String(localized: "Undo")) { [context] in
            undo()
            try? context.save()
        }
    }

    private func remove() {
        context.delete(book)
        try? context.save()
        onRemoved()
        if showsBack { dismiss() }
    }
}

// MARK: - Move to shelf (Flow 7 › Step 3)

struct MoveToShelfSheet: View {
    let book: Book
    let onRemove: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @State private var height: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Move to shelf")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            group {
                ForEach(Array(ReadingStatus.shelves.enumerated()), id: \.element) { index, status in
                    if index > 0 { theme.palette.line.frame(height: 0.75) }
                    row(icon: status.icon, title: status.bookLabel, tint: theme.palette.ink,
                        tile: theme.palette.soft2, iconTint: theme.palette.accentInk,
                        selected: book.status == status) { choose(status) }
                }
            }
            group {
                row(icon: "qs.trash", title: String(localized: "Remove from library"), tint: theme.palette.error,
                    tile: theme.palette.errorSoft, iconTint: theme.palette.error, selected: false) {
                    dismiss()
                    onRemove()
                }
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
    }

    private func group<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card - 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.card - 4, style: .continuous)
                .strokeBorder(theme.palette.line, lineWidth: 0.75))
    }

    private func row(icon: String, title: String, tint: Color, tile: Color, iconTint: Color,
                     selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s12) {
                Image(icon)
                    .resizable()
                    .frame(width: Size.iconM, height: Size.iconM)
                    .foregroundStyle(iconTint)
                    .frame(width: Space.s32, height: Space.s32)
                    .background(tile, in: RoundedRectangle(cornerRadius: theme.radii.inner + 2, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image("qs.check")
                        .resizable()
                        .frame(width: Size.iconM + 2, height: Size.iconM + 2)
                        .foregroundStyle(theme.palette.accentInk)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func choose(_ status: ReadingStatus) {
        guard status != book.status else { dismiss(); return }
        let undo = book.move(to: status)
        try? context.save()
        dismiss()
        // Flow 7 › Step 4 · Moved
        notifications.show(String(localized: "Moved to \(status.shelfName)"),
                           message: String(localized: "You can move it back any time."),
                           kind: .info, actionTitle: String(localized: "Undo")) { [context] in
            undo()
            try? context.save()
        }
    }
}

// MARK: - Moods

private struct MoodsSheet: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var moods: Set<String> = []

    private var options: [String] {
        let base = ["Cozy", "Slow", "Hopeful", "Sad", "Re-read", "Dark", "Funny"]
        return base + book.moods.filter { !base.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("How did it feel?")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Space.s8) {
                ForEach(options, id: \.self) { mood in
                    QsChip(title: String(localized: String.LocalizationValue(mood)), isSelected: moods.contains(mood)) {
                        if moods.contains(mood) { moods.remove(mood) } else { moods.insert(mood) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Save") {
                book.moods = options.filter(moods.contains)
                try? context.save()
                dismiss()
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .padding(.horizontal, Space.s20)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear { moods = Set(book.moods) }
    }
}

// MARK: - Shelf moves

extension Book {
    /// Moves the book to a shelf and returns a closure that puts everything back (for Undo).
    func move(to newStatus: ReadingStatus) -> () -> Void {
        let previous = (status, dateFinished, currentPage, lastUpdated)
        status = newStatus
        lastUpdated = .now
        switch newStatus {
        case .read:
            dateFinished = dateFinished ?? .now
            if let pageCount { currentPage = pageCount }
        case .reading, .toRead, .stopped:
            break
        }
        return { [weak self] in
            guard let self else { return }
            (self.status, self.dateFinished, self.currentPage, self.lastUpdated) = previous
        }
    }
}
