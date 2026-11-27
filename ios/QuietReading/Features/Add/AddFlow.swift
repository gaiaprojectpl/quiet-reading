import SwiftUI
import SwiftData
import AVFoundation

/// Camera colours come from Figma's `c/system/*` variables (the same in every theme).
nonisolated enum QsSystemColor {
    static let camera = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255) // c/system/camera
    static let viewfinder = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2A / 255)
    static let onCamera = Color.white                                                // c/system/onCamera
}

enum AddMode: Hashable { case cover, barcode, type }

/// Flow 2 · Add a book: Photograph the cover / Scan the barcode / Type → Is this the book? → Added.
struct AddFlow: View {
    @State var mode: AddMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = CameraController()
    @State private var status: Status = .idle
    @State private var confirm: Confirmation?
    @State private var noMatch: NoMatch?
    @State private var cameraDenied = false
    @State private var cameraAllowed = false

    private enum Status: Equatable { case idle, reading, searching, tooDark, notAvailable }

    struct Confirmation: Identifiable {
        let id = UUID()
        var candidates: [BookCandidate]
        var photo: UIImage?
    }

    struct NoMatch: Identifiable {
        let id = UUID()
        var photo: UIImage?
        var title: String
        var author: String
    }

    var body: some View {
        Group {
            if mode == .type {
                TypeSearchView(mode: $mode, onPick: { picked, results in
                    confirm = Confirmation(candidates: [picked] + results.filter { $0.id != picked.id }.prefix(2), photo: nil)
                }, onCancel: { dismiss() })
            } else {
                cameraScreen
            }
        }
        .sheet(item: $confirm) { c in
            ConfirmEditionSheet(candidates: c.candidates, photo: c.photo, onAdded: { dismiss() })
        }
        .fullScreenCover(item: $noMatch) { n in
            NoMatchView(photo: n.photo, title: n.title, author: n.author, onDone: { noMatch = nil; dismiss() })
        }
        .alert("Allow camera access?", isPresented: $cameraDenied) {
            Button("Not now", role: .cancel) { mode = .type }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text("Quiet Reading uses the camera only to read covers and barcodes. Photos stay on your phone.")
        }
        .task(id: mode) { await checkCamera() }
        #if DEBUG
        // Test builds only: `-qsAdd confirm | nomatch`.
        .task {
            switch UserDefaults.standard.string(forKey: "qsAdd") {
            case "confirm":
                let results = await BookSearch.search("The Secret Garden Burnett")
                if !results.isEmpty { confirm = Confirmation(candidates: Array(results.prefix(3)), photo: nil) }
            case "nomatch": noMatch = NoMatch(photo: nil, title: "Sól i strony", author: "Frances Hodgson Burnett")
            default: break
            }
        }
        #endif
        .onDisappear { camera.torchOff() }
    }

    // MARK: Camera (Flow 2 › Step 3)

    private var cameraScreen: some View {
        VStack(spacing: Space.s16) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(QsSystemColor.onCamera)
                    .frame(minHeight: Size.touchIos)
                Spacer()
                Button { camera.toggleTorch() } label: {
                    Image("qs.flash")
                        .resizable()
                        .frame(width: Size.iconL, height: Size.iconL)
                        .foregroundStyle(camera.torchOn ? Color.yellow : QsSystemColor.onCamera)
                        .frame(width: Size.touchIos, height: Size.touchIos)
                }
                .accessibilityLabel(camera.torchOn ? "Turn off the flash" : "Turn on the flash")
            }
            viewfinder
            statusPill
            Spacer(minLength: 0)
            modePicker(dark: true)
            if mode == .cover {
                Button(action: shoot) {
                    Circle()
                        .strokeBorder(QsSystemColor.onCamera, lineWidth: 4)
                        .background(Circle().fill(QsSystemColor.onCamera).padding(Space.s8))
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(QsPressStyle())
                .disabled(status == .reading || status == .searching || !cameraAllowed)
                .accessibilityLabel("Take photo")
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s8)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .background(QsSystemColor.camera.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var viewfinder: some View {
        ZStack {
            QsSystemColor.viewfinder
            if cameraAllowed, CameraScanner.isAvailable {
                CameraScanner(kind: mode == .barcode ? .barcode : .cover, controller: camera, onISBN: lookup)
                    .id(mode)
            } else if status == .notAvailable {
                Text("The camera isn’t available here. Type the title instead.")
                    .font(.subheadline)
                    .foregroundStyle(QsSystemColor.onCamera.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(Space.s24)
            }
            ViewfinderCorners()
                .padding(Space.s24)
                .allowsHitTesting(false)
            if status == .tooDark {
                Color.black.opacity(0.4).allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous))
        .frame(maxHeight: 470)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .barcode ? "Camera. Point at the barcode on the back of the book." : "Camera. Fill the frame with the cover.")
    }

    @ViewBuilder private var statusPill: some View {
        let (text, isError): (LocalizedStringKey, Bool) = switch status {
        case .tooDark: ("Too dark. Turn on the light or the flash.", true)
        case .reading: ("Hold still… reading the title", false)
        case .searching: ("Looking for the book…", false)
        case .notAvailable: ("Type works without the camera", false)
        case .idle: (mode == .barcode ? "Point at the barcode on the back" : "Fill the frame with the cover", false)
        }
        HStack(spacing: Space.s8) {
            if isError {
                Image("qs.alert").resizable().frame(width: Size.iconS + 2, height: Size.iconS + 2).accessibilityHidden(true)
            }
            Text(text).font(.subheadline.weight(.medium))
        }
        .foregroundStyle(QsSystemColor.onCamera)
        .padding(.horizontal, Space.s16)
        .padding(.vertical, Space.s8)
        .background(isError ? theme.palette.error : Color.black.opacity(0.6), in: Capsule())
        .gentleAnimation(status)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func modePicker(dark: Bool) -> some View {
        ModePicker(mode: $mode, dark: dark)
    }

    // MARK: Actions

    private func checkCamera() async {
        guard mode != .type else { return }
        guard CameraScanner.isAvailable else { status = .notAvailable; cameraAllowed = false; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraAllowed = true
        case .notDetermined:
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            if !cameraAllowed { cameraDenied = true }
        default: cameraDenied = true
        }
        status = .idle
    }

    private func shoot() {
        Task {
            status = .reading
            guard let photo = await camera.capturePhoto() else { status = .idle; return }
            let read = await CoverReader.read(photo)
            if read.isTooDark { status = .tooDark; return }
            status = .searching
            let results = await BookSearch.search(read.query)
            status = .idle
            if results.isEmpty {
                noMatch = NoMatch(photo: photo, title: read.lines.first ?? "", author: read.lines.dropFirst().first ?? "")
            } else {
                confirm = Confirmation(candidates: Array(results.prefix(3)), photo: photo)
            }
        }
    }

    private func lookup(isbn: String) {
        guard status != .searching, confirm == nil else { return }
        Task {
            status = .searching
            let results = await BookSearch.lookup(isbn: isbn)
            status = .idle
            if results.isEmpty {
                noMatch = NoMatch(photo: nil, title: "", author: "")
            } else {
                confirm = Confirmation(candidates: Array(results.prefix(3)), photo: nil)
            }
        }
    }
}

// MARK: - Pieces

/// Cover / Barcode / Type switch (dark on the camera, light on Type).
private struct ModePicker: View {
    @Binding var mode: AddMode
    let dark: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.s4) {
            item("Cover", .cover)
            item("Barcode", .barcode)
            item("Type", .type)
        }
        .padding(Space.s4)
        .background(dark ? Color.white.opacity(0.14) : theme.palette.soft2, in: Capsule())
        .gentleAnimation(mode, duration: Motion.fast)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private func item(_ title: LocalizedStringKey, _ m: AddMode) -> some View {
        let selected = mode == m
        return Button { mode = m } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? (dark ? QsSystemColor.camera : theme.palette.ink) : (dark ? QsSystemColor.onCamera : theme.palette.ink))
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
                .background(selected ? (dark ? Color.white : theme.palette.surface) : .clear, in: Capsule())
                .frame(minHeight: Size.touchIos - Space.s8)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// The four corner marks of the viewfinder.
private struct ViewfinderCorners: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width, h = geo.size.height, l: CGFloat = 16
                p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
                p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
                p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
                p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(QsSystemColor.onCamera, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Type (search by title or author)

struct TypeSearchView: View {
    @Binding var mode: AddMode
    let onPick: (BookCandidate, [BookCandidate]) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) private var theme
    @Environment(Connectivity.self) private var connectivity
    @Environment(NotificationCenterModel.self) private var notifications
    @State private var slow = false
    @State private var addingByHand = false
    @State private var query = ""
    @State private var results: [BookCandidate] = []
    @State private var searching = false
    @State private var searched = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack {
                QsBackButton(title: "Cancel", action: onCancel)
                Spacer()
            }
            Text("Search by title or author")
                .font(theme.headline(28, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Space.s8) {
                Image("qs.search").resizable().frame(width: Size.iconM, height: Size.iconM)
                    .foregroundStyle(theme.palette.ink2).accessibilityHidden(true)
                TextField("Title or author", text: $query)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit(search)
            }
            .padding(.horizontal, Space.s16)
            .frame(minHeight: Size.field)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s12) {
                    if !connectivity.isOnline {
                        // Flow 10 › C1 · Search · offline
                        EmptyStateView(icon: "qs.cloudoff", title: "Search needs a connection",
                                       message: "You can still add the book by hand. Its cover and details will fill in when you’re back online.")
                    } else if searching {
                        Text("Searching Open Library and Google Books…")
                            .font(.subheadline).foregroundStyle(theme.palette.ink2)
                        ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                            .accessibilityLabel("Searching")
                    } else if searched && results.isEmpty {
                        InfoBanner(message: "No books found. Check the spelling, or try the author’s name.")
                    } else {
                        ForEach(results) { book in
                            Button { onPick(book, results) } label: { CandidateRow(candidate: book, selected: false) }
                                .buttonStyle(QsPressStyle())
                        }
                    }
                }
                .gentleAnimation(searching)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.s12) {
                if !connectivity.isOnline {
                    Button("Add by hand") { addingByHand = true }
                        .buttonStyle(QsButtonStyle(priority: .primary))
                    Button("Scan the barcode instead") { mode = .barcode }
                        .buttonStyle(QsButtonStyle(priority: .text))
                } else if slow {
                    Button("Add by hand") { addingByHand = true }
                        .buttonStyle(QsButtonStyle(priority: .secondary))
                }
                ModePicker(mode: $mode, dark: false)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        // Offline, keep the keyboard closed so the calm message is readable.
        .onAppear { focused = connectivity.isOnline }
        .fullScreenCover(isPresented: $addingByHand) {
            NoMatchView(photo: nil, title: query, author: "", heading: "Add by hand", showsWarning: false,
                        onDone: { addingByHand = false; onCancel() })
        }
    }

    private func search() {
        guard connectivity.isOnline else { return }
        Task {
            searching = true
            slow = false
            // Flow 10 › B3 · over 8 s: say why and offer a way out (the typed text is kept).
            let watchdog = Task {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled, searching else { return }
                slow = true
                notifications.show(String(localized: "Still searching"),
                                   message: String(localized: "Slow connections can take a little longer."), kind: .info)
            }
            results = await BookSearch.search(query)
            watchdog.cancel()
            searching = false
            searched = true
        }
    }
}

/// Loading placeholder in the real layout (Flow 10: disabledBg, no shimmer).
struct SkeletonRow: View {
    @Environment(\.theme) private var theme
    var body: some View {
        HStack(spacing: Space.s12) {
            RoundedRectangle(cornerRadius: theme.radii.cover).fill(theme.palette.disabledBg).frame(width: 44, height: 66)
            VStack(alignment: .leading, spacing: Space.s8) {
                Capsule().fill(theme.palette.disabledBg).frame(height: 12).frame(maxWidth: 180)
                Capsule().fill(theme.palette.disabledBg).frame(height: 10).frame(maxWidth: 120)
            }
            Spacer()
        }
        .padding(Space.s12)
        .accessibilityHidden(true)
    }
}

/// One edition row. Selected: soft2 fill, accent border and a check.
struct CandidateRow: View {
    let candidate: BookCandidate
    let selected: Bool
    @Environment(\.theme) private var theme
    @State private var cover: Data?

    var body: some View {
        HStack(spacing: Space.s12) {
            BookCover(source: .data(cover), title: candidate.title, width: 44)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(candidate.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.palette.ink)
                Text([candidate.author, candidate.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(theme.palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if selected {
                Image("qs.check").resizable().frame(width: Size.iconM + 2, height: Size.iconM + 2)
                    .foregroundStyle(theme.palette.accentInk).accessibilityHidden(true)
            }
        }
        .padding(Space.s12)
        .background(selected ? theme.palette.soft2 : .clear, in: RoundedRectangle(cornerRadius: theme.radii.field + 2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.field + 2, style: .continuous)
            .strokeBorder(selected ? theme.palette.accent : theme.palette.line, lineWidth: Size.stroke))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .task(id: candidate.id) {
            if let url = candidate.coverURL { cover = await BookSearch.download(url) }
        }
    }
}

// MARK: - Is this the book? (Flow 2 › Step 4)

struct ConfirmEditionSheet: View {
    let candidates: [BookCandidate]
    let photo: UIImage?
    let onAdded: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(Connectivity.self) private var connectivity
    @State private var selected: BookCandidate.ID?
    @State private var usePhoto = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("Is this the book?")
                    .font(theme.headline(24, relativeTo: .title2))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                ForEach(candidates) { c in
                    Button { selected = c.id } label: { CandidateRow(candidate: c, selected: selected == c.id) }
                        .buttonStyle(QsPressStyle())
                }
                if photo != nil {
                    Toggle("Use my photo as the cover", isOn: $usePhoto)
                        .font(.callout)
                        .foregroundStyle(theme.palette.ink)
                        .tint(theme.palette.accent)
                        .padding(.vertical, Space.s4)
                }
            }
            .gentleAnimation(selected, duration: Motion.fast)
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.s12) {
                Button("Add to Reading now") { add(.reading) }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                Button("Add to Want to read") { add(.toRead) }
                    .buttonStyle(QsButtonStyle(priority: .secondary))
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.surface)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear { selected = candidates.first?.id }
    }

    private func add(_ status: ReadingStatus) {
        guard let pick = candidates.first(where: { $0.id == selected }) ?? candidates.first else { return }
        BookAdder.add(title: pick.title, author: pick.author, isbn: pick.isbn, pageCount: pick.pageCount,
                      status: status, photo: usePhoto ? photo : nil, coverURL: pick.coverURL,
                      context: context, notifications: notifications, isOnline: connectivity.isOnline)
        dismiss()
        onAdded()
    }
}

// MARK: - We couldn't find this book (Flow 2 › No match)

struct NoMatchView: View {
    let photo: UIImage?
    @State var title: String
    @State var author: String
    var heading: LocalizedStringKey = "We couldn’t find this book"
    var showsWarning = true
    let onDone: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @Environment(Connectivity.self) private var connectivity
    @State private var results: [BookCandidate] = []
    @State private var searching = false
    @State private var confirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                Text(heading)
                    .font(theme.headline(28, relativeTo: .title))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let photo {
                    HStack(spacing: Space.s16) {
                        Image(uiImage: photo)
                            .resizable().scaledToFill()
                            .frame(width: Size.coverM, height: Size.coverM * 1.5)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radii.cover, style: .continuous))
                            .accessibilityHidden(true)
                        Text("Your photo will be the cover.")
                            .font(.subheadline)
                            .foregroundStyle(theme.palette.ink2)
                    }
                }
                field("Title", text: $title)
                field("Author", text: $author)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.s12) {
                Button(searching ? "Searching…" : "Search again", action: searchAgain)
                    .buttonStyle(QsButtonStyle(priority: .primary))
                    .disabled(searching || title.trimmingCharacters(in: .whitespaces).isEmpty)
                Button(photo == nil ? "Add as I typed it" : "Add with my photo", action: addAsIs)
                    .buttonStyle(QsButtonStyle(priority: .secondary))
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .modifier(QsNotificationHost())
        .sheet(isPresented: $confirm) {
            ConfirmEditionSheet(candidates: Array(results.prefix(3)), photo: photo, onAdded: onDone)
        }
        .onAppear {
            guard showsWarning else { return }
            notifications.show(String(localized: "No match for this cover"),
                               message: String(localized: "Try the barcode, or add the book yourself."), kind: .warning)
        }
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
            TextField(label, text: text)
                .font(.body)
                .padding(.horizontal, Space.s16)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
        }
    }

    private func searchAgain() {
        Task {
            searching = true
            results = await BookSearch.search("\(title) \(author)")
            searching = false
            if results.isEmpty {
                notifications.show(String(localized: "Still no match"),
                                   message: String(localized: "You can add it as it is. Details can be changed later."), kind: .warning)
            } else {
                confirm = true
            }
        }
    }

    private func addAsIs() {
        BookAdder.add(title: title.trimmingCharacters(in: .whitespaces), author: author.trimmingCharacters(in: .whitespaces),
                      isbn: nil, pageCount: nil, status: .toRead, photo: photo, coverURL: nil,
                      context: context, notifications: notifications, isOnline: connectivity.isOnline)
        onDone()
    }
}

// MARK: - Adding

enum BookAdder {
    /// Saves the book straight away (works offline); the cover fills in later when it's online.
    static func add(title: String, author: String, isbn: String?, pageCount: Int?, status: ReadingStatus,
                    photo: UIImage?, coverURL: URL?, context: ModelContext, notifications: NotificationCenterModel,
                    isOnline: Bool = true) {
        let book = Book(title: title, author: author, isbn: isbn, pageCount: pageCount, status: status, source: .manual)
        let existing = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        if existing.contains(where: { $0.matchKey == book.matchKey }) {
            notifications.show(String(localized: "Already on your shelf"),
                               message: String(localized: "“\(title)” is in your library."), kind: .info)
            return
        }
        book.coverData = photo?.coverJPEG()
        context.insert(book)
        try? context.save()

        let shelf = status == .reading ? String(localized: "Reading now") : status.shelfName
        // Flow 10 › C2 · Book added offline
        let message = isOnline || book.coverData != nil
            ? String(localized: "“\(title)” is on \(shelf).")
            : String(localized: "Its cover and details will fill in when you’re back online.")
        notifications.show(String(localized: "Book added"),
                           message: message,
                           actionTitle: String(localized: "Undo")) {
            context.delete(book)
            try? context.save()
        }

        if book.coverData == nil {
            Task {
                if let data = await BookSearch.coverData(isbn: isbn, fallbackURL: coverURL) {
                    book.coverData = data
                    try? context.save()
                }
            }
        }
    }
}
