import SwiftUI
import SwiftData
import PencilKit
import Vision
import PhotosUI

/// Flow 6 › Margin notes with Pencil (iPhone Duo, book pose).
/// Left page: a photo of the book page. Underline lines with Apple Pencil → saved as a quote, and the
/// page also updates progress. Right page: the margin, a lined page for handwritten notes.
/// Left-handed: "Swap sides" puts the margin on the left (remembered).
/// Edge cases: Pencil not connected (a finger tries to write), page can't be read (no text found).
struct MarginNotesView: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoLayout) private var duo
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications
    @AppStorage("writingHandLeft") private var leftHanded = false

    @State private var photo: UIImage?
    @State private var lines: [PageLine] = []
    @State private var pageNumber: Int?
    @State private var reading = false
    @State private var unreadable = false
    @State private var pencilMissing = false
    @State private var saved: [SavedUnderline] = []
    @State private var takingPhoto = false
    @State private var picking = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var marginCanvas = PKCanvasView()
    @State private var marginHasInk = false
    @State private var erasing = false
    @State private var typing = false

    struct PageLine: Equatable { let text: String; let box: CGRect }   // box in normalised top-left coordinates
    struct SavedUnderline: Identifiable { let id = UUID(); let text: String; let page: Int? }

    private var page: Int { pageNumber ?? max(book.currentPage, 1) }

    var body: some View {
        Group {
            if duo.mode == .book {
                HStack(spacing: duo.fold.width) {
                    if leftHanded { marginPane; pagePane } else { pagePane; marginPane }
                }
            } else {
                VStack(spacing: Space.s12) { pagePane; marginPane }
            }
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .overlay(alignment: .top) { banner }
        .animation(.easeOut(duration: Motion.base), value: pencilMissing)
        .animation(.easeOut(duration: Motion.base), value: unreadable)
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraCapture(front: false) { image in load(image) }.ignoresSafeArea()
        }
        .photosPicker(isPresented: $picking, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { load(image) }
                pickedItem = nil
            }
        }
        .sheet(isPresented: $typing) { NoteComposer(book: book) }
        #if DEBUG
        // Test builds: `-qsMarginSample YES` loads a printed sample page (Anne of Green Gables, public domain).
        .task { if UserDefaults.standard.bool(forKey: "qsMarginSample"), photo == nil { load(Self.samplePage()) } }
        #endif
    }

    #if DEBUG
    static func samplePage() -> UIImage {
        let text = "“Marilla, isn’t it nice to think that tomorrow is a new day with no mistakes in it yet?”\n\n“I’ll warrant you’ll make plenty in it,” said Marilla. “I never saw your beat for making mistakes, Anne.”\n\n“Yes, and well I know it,” admitted Anne mournfully. “But have you ever noticed one encouraging thing about me, Marilla? I never make the same mistake twice.”"
        let size = CGSize(width: 900, height: 1300)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.97, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let style = NSMutableParagraphStyle(); style.lineSpacing = 10
            (text as NSString).draw(in: CGRect(x: 80, y: 120, width: 740, height: 1000),
                                    withAttributes: [.font: UIFont(name: "Georgia", size: 34)!, .foregroundColor: UIColor.darkGray, .paragraphStyle: style])
            ("98" as NSString).draw(at: CGPoint(x: 440, y: 1230), withAttributes: [.font: UIFont(name: "Georgia", size: 28)!, .foregroundColor: UIColor.gray])
        }
    }
    #endif

    // MARK: Page (left)

    private var pagePane: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            HStack(spacing: Space.s4) {
                QsBackButton(title: "\(book.title) · page \(page)") { dismiss() }
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button { takingPhoto = true } label: {
                    Image("qs.camera").resizable().frame(width: Size.iconM, height: Size.iconM)
                        .foregroundStyle(theme.palette.ink2)
                        .frame(width: Size.touchIos, height: Size.touchIos).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take a new photo of the page")
            }
            if let photo {
                UnderlinePage(image: photo, lines: lines, ink: UIColor(theme.palette.tintStrong),
                              onUnderline: saveUnderline, onFinger: { pencilMissing = true })
                    .overlay { if reading { ProgressView().controlSize(.large) } }
                Text("Underline with Apple Pencil to save a quote. Page \(page) also updates your progress.")
                    .font(.footnote).foregroundStyle(theme.palette.ink2)
            } else {
                VStack(spacing: Space.s12) {
                    Image("qs.camera").resizable().frame(width: Size.iconL, height: Size.iconL)
                        .foregroundStyle(theme.palette.accentInk)
                        .frame(width: Space.s64, height: Space.s64)
                        .background(theme.palette.soft2, in: Circle())
                        .accessibilityHidden(true)
                    Text("Photograph the page you’re reading").font(theme.headline(20, relativeTo: .title3)).foregroundStyle(theme.palette.ink)
                        .multilineTextAlignment(.center)
                    Text("Then underline lines with Pencil to keep them as quotes.").font(.subheadline).foregroundStyle(theme.palette.ink2)
                        .multilineTextAlignment(.center)
                    Button("Take a photo") { takingPhoto = true }.buttonStyle(QsButtonStyle(priority: .primary, size: .small)).fixedSize()
                    Button("Choose from Photos") { picking = true }.buttonStyle(QsButtonStyle(priority: .text, size: .small)).fixedSize()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            }
        }
        .padding(Space.s16)
        .frame(maxWidth: duo.mode == .book ? (leftHanded ? .infinity : duo.fold.minX) : .infinity, maxHeight: .infinity)
    }

    // MARK: Margin (right)

    private var marginPane: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            HStack(spacing: Space.s4) {
                Text("Margin").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                tool(erasing ? "qs.close" : "qs.pencil", label: erasing ? "Eraser on, tap for pen" : "Pen, tap for eraser") {
                    erasing.toggle()
                    marginCanvas.tool = erasing ? PKEraserTool(.vector) : PKInkingTool(.pen, color: UIColor(theme.palette.ink), width: 3)
                }
                tool("qs.sort", label: "Swap sides") { withAnimation(.easeOut(duration: Motion.base)) { leftHanded.toggle() } }
                tool("qs.trash", label: "Clear the margin") { marginCanvas.drawing = PKDrawing(); marginHasInk = false }
                Button("Done", action: done)
                    .font(.body.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
                    .frame(minWidth: Size.touchIos, minHeight: Size.touchIos)
            }
            HandwritingPad(canvas: $marginCanvas, hasInk: $marginHasInk)
                .frame(maxHeight: .infinity)
            ForEach(saved.suffix(2)) { s in
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text("SAVED FROM YOUR UNDERLINE").font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(theme.palette.ink2)
                    Text("“\(s.text)”").font(theme.headline(15, relativeTo: .body)).foregroundStyle(theme.palette.ink).lineLimit(3)
                    if let p = s.page { Text("p. \(p) · progress set to page \(p)").font(.caption).foregroundStyle(theme.palette.ink2) }
                }
                .padding(Space.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.successSoft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .accessibilityElement(children: .combine)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(Space.s16)
        .padding(.bottom, QsLayout.actionsAboveBottomLine - Space.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: Motion.base), value: saved.count)
    }

    private func tool(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon).resizable().frame(width: Size.iconM, height: Size.iconM)
                .foregroundStyle(theme.palette.ink2)
                .frame(width: Size.touchIos, height: Size.touchIos).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Banners (edge cases)

    @ViewBuilder private var banner: some View {
        if pencilMissing {
            notice(icon: "qs.info", title: "Apple Pencil not connected", message: "Connect it to write, or type a note instead.",
                   fill: theme.palette.successSoft, actionTitle: "Type a note", action: { pencilMissing = false; typing = true }) { pencilMissing = false }
        } else if unreadable {
            notice(icon: "qs.alert", title: "We couldn’t read this page", message: "Hold the book flat, in good light, and try again.",
                   fill: theme.palette.errorSoft, actionTitle: "Take the photo again", action: { unreadable = false; takingPhoto = true }) { unreadable = false }
        }
    }

    private func notice(icon: String, title: LocalizedStringKey, message: LocalizedStringKey, fill: Color,
                        actionTitle: LocalizedStringKey, action: @escaping () -> Void, close: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: Space.s12) {
            Image(icon).resizable().frame(width: Size.iconM, height: Size.iconM).foregroundStyle(theme.palette.ink).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline)
                Button(actionTitle, action: action).font(.subheadline.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
                    .frame(minHeight: Size.touchIos)
            }
            .foregroundStyle(theme.palette.ink)
            Spacer(minLength: 0)
            Button(action: close) {
                Image("qs.close").resizable().frame(width: Size.iconS, height: Size.iconS).foregroundStyle(theme.palette.ink2)
                    .frame(width: Size.touchIos, height: Size.touchIos)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(Space.s12)
        .background(fill, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .shadow(color: theme.palette.scrim.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, Space.s16)
        .padding(.top, Space.s8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }

    // MARK: Actions

    private func load(_ image: UIImage) {
        photo = image
        lines = []
        reading = true
        unreadable = false
        Task {
            let result = await PageText.read(image)
            lines = result.lines
            pageNumber = result.page
            reading = false
            if result.lines.isEmpty { unreadable = true }
        }
    }

    /// Lines underlined with Pencil become a quote; the page also updates progress (never backwards).
    private func saveUnderline(_ text: String) {
        let quote = Quote(text: text, page: pageNumber, mood: nil, showOnWidget: true, fromPhoto: true)
        quote.book = book
        context.insert(quote)
        if let p = pageNumber, p > book.currentPage, book.pageCount.map({ p <= $0 }) ?? true {
            let session = ReadingSession(fromPage: book.currentPage, toPage: p)
            session.book = book
            context.insert(session)
            book.currentPage = p
            book.lastUpdated = .now
        }
        try? context.save()
        saved.append(SavedUnderline(text: text, page: pageNumber))
    }

    /// Done: the margin becomes a handwritten note for this page (text read on the phone).
    private func done() {
        guard marginHasInk else { dismiss(); return }
        let drawing = marginCanvas.drawing
        let p = page
        Task {
            let text = await HandwritingReader.text(from: drawing)
            let session = ReadingSession(fromPage: p, toPage: p, note: text.isEmpty ? String(localized: "Margin note") : text)
            session.noteDrawing = drawing.dataRepresentation()
            session.book = book
            context.insert(session)
            try? context.save()
            notifications.show(String(localized: "Margin note saved"), message: String(localized: "It’s in this book’s notes, page \(p)."))
            dismiss()
        }
    }
}

// MARK: - Page photo with a Pencil layer for underlining

private struct UnderlinePage: View {
    let image: UIImage
    let lines: [MarginNotesView.PageLine]
    let ink: UIColor
    let onUnderline: (String) -> Void
    let onFinger: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            let fit = fitted(image.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image).resizable().frame(width: fit.width, height: fit.height)
                UnderlineCanvas(size: fit, lines: lines, ink: ink, onUnderline: onUnderline, onFinger: onFinger)
                    .frame(width: fit.width, height: fit.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.inner, style: .continuous))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo of the page. Underline lines with Apple Pencil to save a quote.")
    }

    private func fitted(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

private struct UnderlineCanvas: UIViewRepresentable {
    let size: CGSize
    let lines: [MarginNotesView.PageLine]
    let ink: UIColor
    let onUnderline: (String) -> Void
    let onFinger: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .pencilOnly
        canvas.tool = PKInkingTool(.marker, color: ink, width: 6)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        let finger = FingerDetector(target: context.coordinator, action: #selector(Coordinator.finger))
        canvas.addGestureRecognizer(finger)
        return canvas
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: UnderlineCanvas
        private var seen = 0
        private var pending: [Int: String] = [:]
        private var timer: Timer?

        init(parent: UnderlineCanvas) { self.parent = parent }

        @objc func finger() { parent.onFinger() }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            defer { seen = strokes.count }
            guard strokes.count > seen, let stroke = strokes.last else { return }
            let b = stroke.renderBounds
            // An underline is long and flat.
            guard b.width > 24, b.height < max(20, b.width * 0.35) else { return }
            let w = parent.size.width, h = parent.size.height
            for (i, line) in parent.lines.enumerated() {
                let r = CGRect(x: line.box.minX * w, y: line.box.minY * h, width: line.box.width * w, height: line.box.height * h)
                let overlap = min(b.maxX, r.maxX) - max(b.minX, r.minX)
                let below = b.midY >= r.minY + r.height * 0.3 && b.midY <= r.maxY + r.height * 0.9
                if below, overlap > b.width * 0.3 { pending[i] = line.text }
            }
            // Several underlines in a row become one quote, a moment after the last one.
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.flush() }
            }
        }

        private func flush() {
            guard !pending.isEmpty else { return }
            let text = pending.keys.sorted().compactMap { pending[$0] }.joined(separator: " ")
                .replacingOccurrences(of: "- ", with: "")
            pending = [:]
            parent.onUnderline(text)
        }
    }
}

/// Notices finger touches on a Pencil-only canvas ("Apple Pencil not connected").
private final class FingerDetector: UIGestureRecognizer {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.contains(where: { $0.type == .direct }) { state = .recognized } else { state = .failed }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

/// Reads a page photo on the phone: text lines with their positions, and the page number if printed.
nonisolated enum PageText {
    struct Result: Sendable { let lines: [MarginNotesView.PageLine]; let page: Int? }

    static func read(_ image: UIImage) async -> Result {
        guard let cg = image.normalisedCG() else { return Result(lines: [], page: nil) }
        return await withCheckedContinuation { c in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                var lines: [MarginNotesView.PageLine] = []
                var page: Int?
                for o in obs {
                    guard let t = o.topCandidates(1).first?.string else { continue }
                    let bb = o.boundingBox
                    let box = CGRect(x: bb.minX, y: 1 - bb.maxY, width: bb.width, height: bb.height)
                    let trimmed = t.trimmingCharacters(in: .whitespaces)
                    // A short number on its own at the very top or bottom is the page number.
                    if let n = Int(trimmed), trimmed.count <= 4, box.minY < 0.1 || box.maxY > 0.9 { page = n; continue }
                    lines.append(.init(text: trimmed, box: box))
                }
                c.resume(returning: Result(lines: lines.sorted { $0.box.minY < $1.box.minY }, page: page))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cg).perform([request])
        }
    }
}

extension MarginNotesView.PageLine: @unchecked Sendable {}

private extension UIImage {
    /// Pixels upright (camera photos carry an orientation flag Vision would otherwise ignore).
    nonisolated func normalisedCG() -> CGImage? {
        if imageOrientation == .up { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }
}
