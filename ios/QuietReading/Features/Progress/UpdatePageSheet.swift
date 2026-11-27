import SwiftUI
import SwiftData

/// Flow 3 › Step 2 · Update page (+ "Page is higher than the book").
/// Progress is typed – the number keyboard opens straight away. Finished + Update sit 24 pt above the keyboard.
struct UpdatePageSheet: View {
    let book: Book
    /// Called when the reader taps Finished / Mark as finished – Home then shows the Finished moment.
    var onFinish: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(NotificationCenterModel.self) private var notifications

    private enum Mode: Hashable { case page, percent }
    private enum Field: Hashable { case value, note }
    @State private var mode: Mode = .page
    @State private var value: Int?
    @State private var note = ""
    @FocusState private var focus: Field?

    private var pages: Int? { book.pageCount }

    /// The page this update would move to.
    private var newPage: Int? {
        guard let value else { return nil }
        switch mode {
        case .page: return value
        case .percent: return pages.map { Int((Double($0) * Double(min(value, 100)) / 100).rounded()) }
        }
    }

    private var tooHigh: Bool {
        guard let pages, let value else { return false }
        return mode == .page ? value > pages : value > 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            Text("Where are you now?")
                .font(theme.headline(24, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            if pages != nil { modePicker }
            numberField
            if tooHigh, let pages {
                InfoBanner(message: "This book has \(pages) pages. Did you finish it?", kind: .error)
            }
            noteField
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s24)
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
        .onAppear {
            value = book.currentPage > 0 ? book.currentPage : nil
            focus = .value
        }
    }

    // MARK: Parts

    /// Page / Percent. (Time comes with the reading timer in the widgets phase.)
    private var modePicker: some View {
        HStack(spacing: Space.s4) {
            segment("Page", .page)
            segment("Percent", .percent)
        }
        .padding(Space.s4)
        .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
    }

    private func segment(_ title: LocalizedStringKey, _ m: Mode) -> some View {
        Button {
            guard mode != m else { return }
            // Keep the same position when switching.
            if let pages, let current = newPage {
                value = m == .percent ? Int((Double(current) / Double(pages) * 100).rounded()) : current
            }
            mode = m
        } label: {
            Text(title)
                .font(.subheadline.weight(mode == m ? .semibold : .regular))
                .foregroundStyle(theme.palette.ink)
                .frame(maxWidth: .infinity, minHeight: Size.touchIos - Space.s8)
                .background(mode == m ? theme.palette.surface : .clear,
                            in: RoundedRectangle(cornerRadius: theme.radii.inner, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == m ? [.isSelected] : [])
    }

    private var numberField: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(mode == .page ? "Page" : "Percent")
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.palette.ink2)
            HStack(spacing: Space.s8) {
                TextField(mode == .page ? "Page" : "Percent", value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .value)
                    .font(theme.headline(20, relativeTo: .title3))
                    .foregroundStyle(tooHigh ? theme.palette.error : theme.palette.ink)
                    .accessibilityLabel(mode == .page ? "Page" : "Percent")
                if let pages {
                    Text(mode == .page ? "of \(pages)" : "%")
                        .font(.body)
                        .foregroundStyle(theme.palette.ink2)
                }
                if tooHigh {
                    Image("qs.alert")
                        .resizable()
                        .frame(width: Size.iconM + 2, height: Size.iconM + 2)
                        .foregroundStyle(theme.palette.error)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.s16)
            .frame(minHeight: Size.field)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                .strokeBorder(tooHigh ? theme.palette.error : theme.palette.lineStrong, lineWidth: Size.stroke))
            if let helper {
                Text(helper)
                    .font(.footnote)
                    .foregroundStyle(tooHigh ? theme.palette.error : theme.palette.ink2)
            }
        }
    }

    /// "26 pages since last time · about 2 h 50 min left" – or the error.
    private var helper: String? {
        if tooHigh, let pages { return mode == .page ? String(localized: "This book has \(pages) pages.") : String(localized: "Up to 100%.") }
        guard let page = newPage else { return nil }
        var parts: [String] = []
        let since = page - book.currentPage
        if since > 0 { parts.append(since == 1 ? String(localized: "1 page since last time") : String(localized: "\(since) pages since last time")) }
        if let left = book.minutesLeft(fromPage: page) {
            parts.append(ReadingTime.left(left).lowercased())
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("Note (optional)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.palette.ink2)
            TextField("Note (optional)", text: $note, axis: .vertical)
                .focused($focus, equals: .note)
                .font(.body)
                .lineLimit(1...3)
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
        }
    }

    private var actions: some View {
        HStack(spacing: Space.s12) {
            if tooHigh {
                Button("Edit page") { focus = .value }
                    .buttonStyle(QsButtonStyle(priority: .secondary))
                Button("Mark as finished", action: finish)
                    .buttonStyle(QsButtonStyle(priority: .primary))
            } else {
                Button("Finished", action: finish)
                    .buttonStyle(QsButtonStyle(priority: .secondary))
                Button("Update", action: save)
                    .buttonStyle(QsButtonStyle(priority: .primary))
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s16)
        .padding(.bottom, QsLayout.actionsAboveBottomLine) // above the keyboard
        .background(theme.palette.surface)
    }

    // MARK: Actions

    private func finish() {
        dismiss()
        onFinish()
    }

    private func save() {
        guard let page = newPage, !tooHigh else { return }
        let target = max(0, page)
        let previous = book.currentPage
        guard target != previous || !note.isEmpty else { dismiss(); return }

        let session = ReadingSession(fromPage: previous, toPage: target, note: note.isEmpty ? nil : note)
        session.book = book
        context.insert(session)
        book.currentPage = target
        book.lastUpdated = .now
        try? context.save()
        dismiss()

        // Flow 3 › Step 3 · Saved: "Page 168 saved · About 2 h 50 min left. Lovely." with Undo.
        let message = book.minutesLeft().map { ReadingTime.left($0) + ". " + String(localized: "Lovely.") } ?? String(localized: "Lovely.")
        let book = book
        let context = context
        notifications.show(String(localized: "Page \(target) saved"), message: message, actionTitle: String(localized: "Undo")) {
            book.currentPage = previous
            context.delete(session)
            try? context.save()
        }
    }
}
