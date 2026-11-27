import SwiftUI

/// 🧱 Components › List row with an icon tile, title, optional subtitle and chevron.
/// Used in "Bring your books" and the Add sheet. Put rows inside `QsListCard`.
struct QsListRow: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let action: () -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var tile = Space.s40
    @ScaledMetric(relativeTo: .body) private var glyph = Size.iconM + 2

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s16) {
                Image(icon)
                    .resizable()
                    .frame(width: glyph, height: glyph)
                    .foregroundStyle(theme.palette.accentInk)
                    .frame(width: tile, height: tile)
                    .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(theme.palette.ink)
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(theme.palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("qs.chevron")
                    .resizable()
                    .frame(width: Size.iconS + 2, height: Size.iconS + 2)
                    .foregroundStyle(theme.palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(Space.s16)
            .frame(minHeight: Size.touchIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Surface card holding `QsListRow`s with dividers between them.
struct QsListCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { theme.palette.line.frame(height: Size.stroke) }
                    row
                }
            }
        }
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .strokeBorder(theme.palette.line, lineWidth: Size.stroke))
    }
}
