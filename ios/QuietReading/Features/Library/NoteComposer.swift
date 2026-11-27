import SwiftUI
import SwiftData
import PencilKit
import Vision

/// Book details › Notes › "Add a note".
/// iPhone: typed. iPhone Duo: Type | Write switch, Write (Pencil) is the default the first time,
/// then it remembers the reader's last choice. Handwriting is kept as a drawing and read on the phone
/// into text, so the note stays searchable, readable by VoiceOver and visible to Astrid (if notes are on).
struct NoteComposer: View {
    let book: Book
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoLayout) private var duo
    @Environment(\.modelContext) private var context
    @AppStorage("noteInputMode") private var savedMode = "write"
    @State private var mode: Mode = .type
    @State private var text = ""
    @State private var page = ""
    @State private var canvas = PKCanvasView()
    @State private var hasInk = false
    @State private var saving = false
    @FocusState private var focus: Field?

    enum Mode: String { case type, write }
    private enum Field { case text, page }

    private var canWrite: Bool { duo.mode != .phone }
    private var canSave: Bool { mode == .write ? hasInk : !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack {
                Text("New note").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                pageField
            }
            if canWrite {
                QsSegmented(options: [(Mode.write, String(localized: "Write")), (.type, String(localized: "Type"))], selection: $mode)
            }
            Group {
                if mode == .write {
                    HandwritingPad(canvas: $canvas, hasInk: $hasInk)
                        .transition(.opacity)
                } else {
                    TextField("What’s on your mind about this book?", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($focus, equals: .text)
                        .font(.body)
                        .padding(Space.s16)
                        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                            .strokeBorder(focus == .text ? theme.palette.focus : theme.palette.lineStrong,
                                          lineWidth: focus == .text ? Size.focusRing : Size.stroke))
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: save) {
                if saving { ProgressView().tint(theme.palette.onAccent) } else { Text("Save note") }
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .disabled(!canSave || saving)
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .gentleAnimation(mode)
        .presentationDetents([.large])
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear {
            page = book.currentPage > 0 ? String(book.currentPage) : ""
            mode = canWrite ? (Mode(rawValue: savedMode) ?? .write) : .type
            if mode == .type { focus = .text }
        }
        .onChange(of: mode) { _, m in
            savedMode = m.rawValue
            if m == .type { focus = .text } else { focus = nil }
        }
    }

    /// Page the note belongs to (typed, number keyboard).
    private var pageField: some View {
        HStack(spacing: Space.s4) {
            Text("p.").foregroundStyle(theme.palette.ink2)
            TextField("Page", text: $page)
                .keyboardType(.numberPad)
                .focused($focus, equals: .page)
                .frame(width: Space.s48)
        }
        .font(.subheadline)
        .padding(.horizontal, Space.s12)
        .frame(minHeight: Size.field)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous).strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page")
    }

    private func save() {
        let p = Int(page) ?? book.currentPage
        if mode == .type {
            store(text: text.trimmingCharacters(in: .whitespacesAndNewlines), drawing: nil, page: p)
            return
        }
        saving = true
        let drawing = canvas.drawing
        Task {
            let recognised = await HandwritingReader.text(from: drawing)
            store(text: recognised.isEmpty ? String(localized: "Handwritten note") : recognised, drawing: drawing.dataRepresentation(), page: p)
        }
    }

    private func store(text: String, drawing: Data?, page: Int) {
        let session = ReadingSession(fromPage: page, toPage: page, note: text)
        session.noteDrawing = drawing
        session.book = book
        context.insert(session)
        try? context.save()
        saving = false
        dismiss()   // saving is silent
    }
}

/// Lined paper for Pencil. Finger touches scroll; Pencil writes (on the Duo).
struct HandwritingPad: View {
    @Binding var canvas: PKCanvasView
    @Binding var hasInk: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CanvasRepresentable(canvas: $canvas, hasInk: $hasInk, ink: UIColor(theme.palette.ink))
                .background(
                    // Faint lines every 32 pt, like a notebook.
                    Canvas { ctx, size in
                        var y: CGFloat = 40
                        while y < size.height {
                            ctx.stroke(Path { p in p.move(to: CGPoint(x: 16, y: y)); p.addLine(to: CGPoint(x: size.width - 16, y: y)) },
                                       with: .color(theme.palette.line), lineWidth: 1)
                            y += 32
                        }
                    }
                )
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous).strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
                .accessibilityLabel("Handwriting area. Write with Apple Pencil.")
            if hasInk {
                Button {
                    canvas.drawing = PKDrawing()
                    hasInk = false
                } label: {
                    Text("Clear").font(.footnote.weight(.semibold)).foregroundStyle(theme.palette.accentInk)
                        .frame(minWidth: Size.touchIos, minHeight: Size.touchIos)
                }
                .padding(Space.s4)
            }
            if !hasInk {
                Text("Write with Pencil").font(.footnote).foregroundStyle(theme.palette.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 280)
    }
}

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasInk: Bool
    let ink: UIColor

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .default          // Pencil draws; with no Pencil, a finger can write too
        canvas.tool = PKInkingTool(.pen, color: ink, width: 3)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.tool = PKInkingTool(.pen, color: ink, width: 3)
    }

    func makeCoordinator() -> Coordinator { Coordinator(hasInk: $hasInk) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var hasInk: Binding<Bool>
        init(hasInk: Binding<Bool>) { self.hasInk = hasInk }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasInk.wrappedValue = !canvasView.drawing.strokes.isEmpty
        }
    }
}

/// Reads handwriting into text on the phone (Vision). Nothing leaves the device.
nonisolated enum HandwritingReader {
    static func text(from drawing: PKDrawing) async -> String {
        let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        guard !bounds.isEmpty else { return "" }
        let image = await MainActor.run {
            drawing.image(from: bounds, scale: 2)
        }
        // Dark ink on white for the best recognition, whatever the theme colour.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let flat = UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
        guard let cg = flat.cgImage else { return "" }
        return await withCheckedContinuation { c in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                    .compactMap { $0.topCandidates(1).first?.string }
                c.resume(returning: lines.joined(separator: " "))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cg).perform([request])
        }
    }
}

/// A saved handwritten note, drawn in the theme's ink.
struct HandwrittenNoteView: View {
    let data: Data
    @Environment(\.theme) private var theme

    var body: some View {
        if let drawing = try? PKDrawing(data: data) {
            let image = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 2)
            Image(uiImage: image).renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(theme.palette.ink)
                .frame(maxWidth: .infinity, maxHeight: 220, alignment: .leading)
                .accessibilityHidden(true)
        }
    }
}

/// Write a short note with Pencil (Update page on the Duo). Returns the recognised text and the drawing.
struct HandwritingSheet: View {
    let onDone: (String, Data) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var hasInk = false
    @State private var reading = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Write a note").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            HandwritingPad(canvas: $canvas, hasInk: $hasInk)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Space.s12) {
                Button("Cancel") { dismiss() }.buttonStyle(QsButtonStyle(priority: .outline))
                Button {
                    reading = true
                    let drawing = canvas.drawing
                    Task {
                        let text = await HandwritingReader.text(from: drawing)
                        onDone(text.isEmpty ? String(localized: "Handwritten note") : text, drawing.dataRepresentation())
                        dismiss()
                    }
                } label: {
                    if reading { ProgressView().tint(theme.palette.onAccent) } else { Text("Use note") }
                }
                .buttonStyle(QsButtonStyle(priority: .primary))
                .disabled(!hasInk || reading)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(theme.radii.sheet)
    }
}
