import SwiftUI
import PencilKit
import SwiftData
import Vision

/// Flow 9 · Add a quote: Photograph the page → Select lines → New quote → Saved.

enum QuoteSource: Identifiable { case photo, typed; var id: Self { self } }

// MARK: - Add a quote sheet (Step 2)

struct AddQuoteSheet: View {
    let onChoose: (QuoteSource) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 260
    @Environment(\.duoLayout) private var duo

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Add a quote")
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            QsListCard {
                QsListRow(icon: "qs.barcode", title: "Photograph the page",
                          subtitle: "Select the lines. Text is read on your phone.") { choose(.photo) }
                if duo.mode != .phone {
                    QsListRow(icon: "qs.pencil", title: "Type or write", subtitle: "Write with Pencil or type it in.") { choose(.typed) }
                } else {
                    QsListRow(icon: "qs.quote", title: "Type or paste") { choose(.typed) }
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

    private func choose(_ source: QuoteSource) {
        onChoose(source)
        dismiss()
    }
}

// MARK: - Container

struct QuoteFlow: View {
    let book: Book
    let source: QuoteSource
    @Environment(\.dismiss) private var dismiss
    @State private var draft: QuoteDraft?

    struct QuoteDraft: Identifiable {
        let id = UUID()
        var text: String
        var page: Int?
        var fromPhoto: Bool
    }

    var body: some View {
        Group {
            if source == .typed || draft != nil {
                QuoteEditor(book: book, draft: draft ?? QuoteDraft(text: "", page: book.currentPage > 0 ? book.currentPage : nil, fromPhoto: false),
                            onDone: { dismiss() })
                    .themedColorScheme()
            } else {
                PageScanner(onUse: { text, page in draft = QuoteDraft(text: text, page: page, fromPhoto: true) },
                            onType: { draft = QuoteDraft(text: "", page: nil, fromPhoto: false) },
                            onCancel: { dismiss() })
            }
        }
        .modifier(QsNotificationHost())
    }
}

// MARK: - Photograph the page + Select lines (Step 3)

struct PageScanner: View {
    let onUse: (String, Int?) -> Void
    let onType: () -> Void
    let onCancel: () -> Void
    @Environment(\.theme) private var theme
    @State private var camera = CameraController()
    @State private var photo: UIImage?
    @State private var lines: [PageReader.Line] = []
    @State private var page: Int?
    @State private var selected: Set<Int> = []
    @State private var reading = false
    @State private var noText = false

    var body: some View {
        VStack(spacing: Space.s16) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(QsSystemColor.onCamera)
                    .frame(minHeight: Size.touchIos)
                Spacer()
                Button { camera.toggleTorch() } label: {
                    Image("qs.flash").resizable().frame(width: Size.iconL, height: Size.iconL)
                        .foregroundStyle(camera.torchOn ? Color.yellow : QsSystemColor.onCamera)
                        .frame(width: Size.touchIos, height: Size.touchIos)
                }
                .accessibilityLabel(camera.torchOn ? "Turn off the flash" : "Turn on the flash")
            }
            pageArea
            statusPill
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s8)
        .padding(.bottom, QsLayout.actionsAboveBottomLine)
        .background(QsSystemColor.camera.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onDisappear { camera.torchOff() }
        #if DEBUG
        .task {
            // Test builds only: `-qsQuote select` reads a generated sample page (the simulator has no camera).
            if UserDefaults.standard.string(forKey: "qsQuote") == "select" { await read(PageReader.samplePage()) }
        }
        #endif
    }

    @ViewBuilder private var pageArea: some View {
        ZStack {
            QsSystemColor.viewfinder
            if let photo {
                GeometryReader { geo in
                    let fitted = fittedRect(image: photo.size, in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: photo).resizable().scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            let r = line.rect(in: fitted)
                            Rectangle()
                                .fill(selected.contains(index) ? theme.palette.accent.opacity(0.85) : Color.white.opacity(0.001))
                                .frame(width: r.width, height: max(r.height, Size.touchIos / 2))
                                .position(x: r.midX, y: r.midY)
                                .onTapGesture {
                                    if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                                }
                                .accessibilityElement()
                                .accessibilityLabel(line.text)
                                .accessibilityAddTraits(selected.contains(index) ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                .gentleAnimation(selected, duration: Motion.fast)
                .sensoryFeedback(.selection, trigger: selected)
            } else if CameraScanner.isAvailable {
                CameraScanner(kind: .cover, controller: camera)
            } else {
                Text("The camera isn’t available here. Type the quote instead.")
                    .font(.subheadline).foregroundStyle(QsSystemColor.onCamera.opacity(0.8))
                    .multilineTextAlignment(.center).padding(Space.s24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous))
    }

    @ViewBuilder private var statusPill: some View {
        let (text, isError): (String, Bool) = {
            if noText { return (String(localized: "No text found. Hold the book flat, in good light."), true) }
            if reading { return (String(localized: "Reading the page…"), false) }
            if photo != nil {
                let count = selected.count
                var t = count == 0 ? String(localized: "Tap the lines you want") : (count == 1 ? String(localized: "1 line selected") : String(localized: "\(count) lines selected"))
                if let page { t += " · " + String(localized: "page \(page) found") }
                return (t, false)
            }
            return (String(localized: "Fill the frame with the page"), false)
        }()
        HStack(spacing: Space.s8) {
            Image(isError ? "qs.alert" : "qs.barcode").resizable().frame(width: Size.iconS, height: Size.iconS).accessibilityHidden(true)
            Text(text).font(.subheadline.weight(.medium))
        }
        .foregroundStyle(QsSystemColor.onCamera)
        .padding(.horizontal, Space.s16)
        .padding(.vertical, Space.s8)
        .background(isError ? theme.palette.error : Color.black.opacity(0.6), in: Capsule())
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: Space.s12) {
            if noText {
                Button("Try again") { photo = nil; noText = false; lines = [] }
                    .buttonStyle(QsButtonStyle(priority: .primary))
            } else if photo != nil {
                Button("Use selection") {
                    let text = selected.sorted().map { lines[$0].text }.joined(separator: " ")
                    onUse(text, page)
                }
                .buttonStyle(QsButtonStyle(priority: .primary))
                .disabled(selected.isEmpty)
            } else {
                Button("Take photo") { Task { if let p = await camera.capturePhoto() { await read(p) } } }
                    .buttonStyle(QsButtonStyle(priority: .primary))
                    .disabled(!CameraScanner.isAvailable || reading)
            }
            Button("Type it instead", action: onType)
                .buttonStyle(QsButtonStyle(priority: .text))
        }
    }

    private func read(_ image: UIImage) async {
        reading = true
        photo = image
        let result = await PageReader.read(image)
        reading = false
        lines = result.lines
        page = result.page
        noText = result.lines.isEmpty
    }

    private func fittedRect(image: CGSize, in box: CGSize) -> CGRect {
        let scale = min(box.width / image.width, box.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (box.width - size.width) / 2, y: (box.height - size.height) / 2, width: size.width, height: size.height)
    }
}

/// Reads a page photo on the phone: text lines with their positions, and the page number if printed.
nonisolated enum PageReader {
    struct Line: Sendable {
        var text: String
        /// Vision's normalised box (origin bottom-left).
        var box: CGRect

        func rect(in frame: CGRect) -> CGRect {
            CGRect(x: frame.minX + box.minX * frame.width,
                   y: frame.minY + (1 - box.maxY) * frame.height,
                   width: box.width * frame.width,
                   height: box.height * frame.height)
        }
    }

    struct Result: Sendable { var lines: [Line]; var page: Int? }

    static func read(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else { return Result(lines: [], page: nil) }
        return await withCheckedContinuation { c in
            let request = VNRecognizeTextRequest { r, _ in
                c.resume(returning: parse((r.results as? [VNRecognizedTextObservation]) ?? []))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            do { try VNImageRequestHandler(cgImage: cg).perform([request]) } catch { c.resume(returning: Result(lines: [], page: nil)) }
        }
    }

    private static func parse(_ observations: [VNRecognizedTextObservation]) -> Result {
        var lines: [Line] = []
        var page: Int?
        for o in observations {
            guard let text = o.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces), !text.isEmpty else { continue }
            // A lone number near the top or bottom edge is the page number.
            if let n = Int(text), n > 0, n < 5000, (o.boundingBox.minY < 0.12 || o.boundingBox.maxY > 0.88) {
                page = n
            } else {
                lines.append(Line(text: text, box: o.boundingBox))
            }
        }
        lines.sort { $0.box.maxY > $1.box.maxY }   // top to bottom
        return Result(lines: lines, page: page)
    }

    #if DEBUG
    /// A printed-looking page for testing on the simulator.
    static func samplePage() -> UIImage {
        let size = CGSize(width: 900, height: 1250)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.97, green: 0.95, blue: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let text = """
            She walked to the end of the garden where the
            old wall leaned into the orchard and the grass
            grew long and silver in the evening wind.
            Light came through the leaves like a slow tide,
            and for a moment nothing needed to be said.
            The house behind her was quiet, the windows
            gold, and the path back felt shorter than before.
            """
            let style = NSMutableParagraphStyle(); style.lineSpacing = 18
            (text as NSString).draw(in: CGRect(x: 70, y: 120, width: 780, height: 900), withAttributes: [
                .font: UIFont(name: "Georgia", size: 38) ?? .systemFont(ofSize: 38), .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
            ("168" as NSString).draw(at: CGPoint(x: 430, y: 1150), withAttributes: [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.gray])
        }
    }
    #endif
}

// MARK: - New quote (Step 4) + Saved (Step 5)

struct QuoteEditor: View {
    let book: Book
    let draft: QuoteFlow.QuoteDraft
    let onDone: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @State private var text = ""
    @State private var page: Int?
    @State private var mood: String?
    @State private var showOnWidget = true
    @State private var triedSave = false
    @FocusState private var focus: Bool
    @Environment(\.duoLayout) private var duo
    @AppStorage(WriteInput.key) private var savedMode = "write"
    @State private var writing = false
    @State private var canvas = PKCanvasView()
    @State private var hasInk = false
    @State private var saving = false

    /// Write (Pencil) is offered on iPhone Duo for typed quotes; photo quotes start from the read text.
    private var canWrite: Bool { duo.mode != .phone && !draft.fromPhoto }

    private static let moods = ["Hopeful", "Cozy", "Sad", "Funny"]
    private var pageMissing: Bool { draft.fromPhoto && page == nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                QsBackButton(title: "Cancel", action: onDone)
                Spacer()
                Text("New quote").font(.body.weight(.semibold)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Color.clear.frame(width: 80, height: 1)
            }
            .padding(.horizontal, Space.s12)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    if text.count > 140 {
                        InfoBanner(message: "Long quotes are fine. The widget shows the first 140 characters.")
                    }
                    if canWrite {
                        QsSegmented(options: [(true, String(localized: "Write")), (false, String(localized: "Type"))], selection: $writing)
                    }
                    if writing {
                        labeled("Quote") {
                            HandwritingPad(canvas: $canvas, hasInk: $hasInk).frame(height: 260)
                        }
                    } else {
                    labeled("Quote") {
                        TextField("Quote", text: $text, axis: .vertical)
                            .font(theme.headline(17, relativeTo: .body))
                            .lineLimit(2...8)
                            .focused($focus)
                            .padding(Space.s16)
                            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                                .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
                        if draft.fromPhoto {
                            helper("Read from your photo. Fix anything we got wrong.")
                        }
                    }
                    }
                    labeled("Page") {
                        HStack {
                            TextField("Page", value: $page, format: .number)
                                .keyboardType(.numberPad)
                                .font(.body)
                            if pageMissing {
                                Image("qs.alert").resizable().frame(width: Size.iconM, height: Size.iconM)
                                    .foregroundStyle(theme.palette.error).accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, Space.s16)
                        .frame(minHeight: Size.field)
                        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                            .strokeBorder(pageMissing ? theme.palette.error : theme.palette.lineStrong, lineWidth: Size.stroke))
                        if pageMissing {
                            Text("We couldn’t see a page number. Type it.").font(.footnote).foregroundStyle(theme.palette.error)
                        } else if draft.fromPhoto, draft.page != nil, page == draft.page {
                            helper("Found on the photo")
                        }
                    }
                    labeled("How did it feel?") {
                        FlowLayout(spacing: Space.s8) {
                            ForEach(Self.moods, id: \.self) { m in
                                QsChip(title: String(localized: String.LocalizationValue(m)), isSelected: mood == m) {
                                    mood = mood == m ? nil : m
                                }
                            }
                        }
                    }
                    Toggle("Show on my quote widget", isOn: $showOnWidget)
                        .font(.callout)
                        .foregroundStyle(theme.palette.ink)
                        .tint(theme.palette.accent)
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s8)
                .padding(.bottom, Space.s24)
                .gentleAnimation(text.count > 140)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: save) {
                if saving { ProgressView().tint(theme.palette.onAccent) } else { Text("Save") }
            }
                .buttonStyle(QsButtonStyle(priority: .primary))
                .disabled((writing ? !hasInk : text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || saving)
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s12)
                .padding(.bottom, QsLayout.actionsAboveBottomLine)
                .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .gentleAnimation(writing)
        .onAppear {
            text = draft.text
            page = draft.page
            writing = canWrite && savedMode == "write"
            if draft.text.isEmpty && !writing { focus = true }
        }
        .onChange(of: writing) { _, w in
            savedMode = w ? "write" : "type"
            focus = w ? false : true
        }
    }

    private func labeled<C: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
            content()
        }
    }

    private func helper(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.footnote).foregroundStyle(theme.palette.ink2)
    }

    private func save() {
        guard writing else { store(text.trimmingCharacters(in: .whitespacesAndNewlines), drawing: nil); return }
        saving = true
        let drawing = canvas.drawing
        Task {
            let read = await HandwritingReader.text(from: drawing)
            store(read.isEmpty ? String(localized: "Handwritten quote") : read, drawing: drawing.dataRepresentation())
        }
    }

    private func store(_ quoteText: String, drawing: Data?) {
        let quote = Quote(text: quoteText, page: page, mood: mood,
                          showOnWidget: showOnWidget, fromPhoto: draft.fromPhoto)
        quote.drawing = drawing
        quote.book = book
        context.insert(quote)
        try? context.save()
        // "It's on your quote widget too" once the widgets exist.
        notifications.show(String(localized: "Quote saved"), message: String(localized: "It’s in your quotes."))
        onDone()
    }
}
