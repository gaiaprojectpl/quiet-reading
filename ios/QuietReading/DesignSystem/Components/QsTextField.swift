import SwiftUI

/// 🧱 Components › Input with its label: label 8 pt above the field (Figma spacing rule),
/// 40 pt field, 1 pt lineStrong border, typed text in ink (never the system's white).
struct QsTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey? = nil
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    @Environment(\.theme) private var theme

    var body: some View {
        QsLabeled(label) {
            TextField(text: $text, prompt: Text(prompt ?? label).foregroundStyle(theme.palette.ink2.opacity(0.75))) { Text(label) }
                .font(.body)
                .foregroundStyle(theme.palette.ink)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .padding(.horizontal, Space.s16)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
        }
    }
}

/// A label 8 pt above any control (text field, menu, Pencil area, chips).
struct QsLabeled<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A menu that looks like a field ("English ⌄"), for short fixed choices.
struct QsMenuField<Value: Hashable>: View {
    let label: LocalizedStringKey
    let options: [(Value, String)]
    @Binding var selection: Value
    @Environment(\.theme) private var theme

    var body: some View {
        QsLabeled(label) {
            Menu {
                Picker(selection: $selection) {
                    ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
                } label: { EmptyView() }
            } label: {
                HStack {
                    Text(options.first { $0.0 == selection }?.1 ?? "").font(.body).foregroundStyle(theme.palette.ink)
                    Spacer()
                    Image("qs.chevron").resizable().frame(width: Size.iconS, height: Size.iconS)
                        .rotationEffect(.degrees(90)).foregroundStyle(theme.palette.ink2)
                }
                .padding(.horizontal, Space.s16)
                .frame(minHeight: Size.field)
                .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                    .strokeBorder(theme.palette.lineStrong, lineWidth: Size.stroke))
                .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(options.first { $0.0 == selection }?.1 ?? ""))
        }
    }
}

/// Book languages offered when adding or editing a book (most read first; "Other" keeps it open).
enum BookLanguage {
    static let all = ["English", "Polish", "German", "French", "Spanish", "Italian", "Portuguese", "Dutch",
                      "Swedish", "Norwegian", "Danish", "Finnish", "Czech", "Ukrainian", "Japanese", "Chinese", "Korean", "Other"]
    static func options() -> [(String, String)] { all.map { ($0, String(localized: String.LocalizationValue($0))) } }
}
