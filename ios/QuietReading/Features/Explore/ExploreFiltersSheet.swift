import SwiftUI

/// Flow 12 › 2 · Filters: genre, length, published, author and language.
/// Changes apply when the reader taps "Show 24 books" (the count is live), Clear resets everything.
struct ExploreFiltersSheet: View {
    @Binding var filters: ExploreFilters
    let text: String
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ExploreFilters()
    @State private var count: Int?
    @State private var authorText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filters").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Clear") { draft = ExploreFilters(); authorText = "" }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(draft.isEmpty ? theme.palette.disabledInk : theme.palette.accentInk)
                    .disabled(draft.isEmpty)
                    .frame(minHeight: Size.touchIos)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s24)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.s20) {
                    group("Genre") {
                        FlowLayout {
                            ForEach(ExploreGenre.allCases) { g in
                                QsChip(title: g.title, isSelected: draft.genres.contains(g)) {
                                    if draft.genres.contains(g) { draft.genres.remove(g) } else { draft.genres.insert(g) }
                                }
                            }
                        }
                    }
                    group("Length") {
                        QsSegmented(options: [(ExploreFilters.Length.any, String(localized: "Any")),
                                              (.under300, String(localized: "Under 300")),
                                              (.over300, String(localized: "300+"))],
                                    selection: $draft.length)
                    }
                    group("Published") {
                        FlowLayout {
                            ForEach([(ExploreFilters.Published.any, String(localized: "Any time")),
                                     (.before1900, String(localized: "Before 1900")),
                                     (.from1900, String(localized: "1900–1999")),
                                     (.since2000, String(localized: "2000 and later"))], id: \.0) { value, title in
                                QsChip(title: title, isSelected: draft.published == value) { draft.published = value }
                            }
                        }
                    }
                    group("Author") {
                        HStack(spacing: Space.s8) {
                            TextField("Any author", text: $authorText)
                                .font(.body)
                                .foregroundStyle(theme.palette.ink)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                            if !authorText.isEmpty {
                                Button { authorText = "" } label: {
                                    Image("qs.close").resizable().frame(width: Size.iconS, height: Size.iconS)
                                        .foregroundStyle(theme.palette.ink2)
                                        .frame(width: Size.touchIos, height: Size.touchIos)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Any author")
                            }
                        }
                        .padding(.leading, Space.s16)
                        .frame(minHeight: Size.field + Space.s4)
                        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                            .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
                    }
                    group("Language") {
                        QsSegmented(options: [(ExploreFilters.Language.english, String(localized: "English")),
                                              (.any, String(localized: "All languages"))],
                                    selection: $draft.language)
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.vertical, Space.s16)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(showTitle) {
                filters = draft
                dismiss()
            }
            .buttonStyle(QsButtonStyle(priority: .primary))
            .disabled(count == 0)
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s12)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .onAppear { draft = filters; authorText = filters.author ?? "" }
        .onChange(of: authorText) { _, a in
            let t = a.trimmingCharacters(in: .whitespaces)
            draft.author = t.isEmpty ? nil : t
        }
        .task(id: "\(draft)") {
            count = nil
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            count = await ExploreCatalog.count(text: text, filters: draft)
        }
    }

    private var showTitle: String {
        guard let count else { return String(localized: "Show books") }
        switch count {
        case 0: return String(localized: "No books match")
        case 1: return String(localized: "Show 1 book")
        default: return String(localized: "Show \(count.formatted()) books")
        }
    }

    private func group<C: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(title).textCase(.uppercase)
                .font(.caption.weight(.semibold)).tracking(0.6)
                .foregroundStyle(theme.palette.ink2)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
