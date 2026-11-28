import SwiftUI

/// 🧱 Components › Search field (Figma 65:9820): search the library or the book catalogue.
/// 40 pt, surface fill, line border, search icon; shows Clear when it has a value.
struct QsSearchField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    var onSubmit: () -> Void = {}
    var focus: FocusState<Bool>.Binding? = nil
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var icon = Size.iconM

    var body: some View {
        HStack(spacing: Space.s8) {
            Image("qs.search")
                .resizable()
                .frame(width: icon, height: icon)
                .foregroundStyle(theme.palette.ink2)
                .accessibilityHidden(true)
            field
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image("qs.close").resizable()
                        .frame(width: Size.iconS, height: Size.iconS)
                        .foregroundStyle(theme.palette.ink2)
                        .frame(width: Size.touchIos, height: Size.touchIos)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -Space.s12)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, Space.s12)
        .frame(minHeight: Size.field)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
            .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
        .frame(minHeight: Size.touchIos)
    }

    @ViewBuilder private var field: some View {
        if let focus {
            TextField(prompt, text: $text).focused(focus)
        } else {
            TextField(prompt, text: $text)
        }
    }
}
