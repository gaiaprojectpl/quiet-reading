import SwiftUI

/// 🧱 Components › List row with an icon tile, title, optional subtitle and chevron.
/// Used in "Bring your books" and the Add sheet. Put rows inside `QsListCard`.
struct QsListRow: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    /// Current value shown before the chevron ("Peach & Sage", "30 books").
    var value: String? = nil
    /// nil = information only: no chevron, not tappable.
    var action: (() -> Void)?
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var tile = Space.s40
    @ScaledMetric(relativeTo: .body) private var glyph = Size.iconM + 2

    var body: some View {
        if let action {
            Button(action: action) { row(chevron: true) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
        } else {
            row(chevron: false)
                .accessibilityElement(children: .combine)
        }
    }

    /// "qs.logo" draws the mini app icon (Figma › Row · App icon): the q on an accent tile, as big as the other glyphs.
    @ViewBuilder private var iconView: some View {
        if icon == "qs.logo" {
            Image("qs.logo").resizable()
                .foregroundStyle(theme.palette.bg)
                .frame(width: glyph, height: glyph)
                .background(theme.palette.accent, in: RoundedRectangle(cornerRadius: glyph / 4, style: .continuous))
        } else {
            Image(icon).resizable()
                .frame(width: glyph, height: glyph)
                .foregroundStyle(theme.palette.accentInk)
        }
    }

    private func row(chevron: Bool) -> some View {
            HStack(spacing: Space.s16) {
                iconView
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
                if let value {
                    Text(value).font(.subheadline).foregroundStyle(theme.palette.ink2)
                }
                if chevron {
                    Image("qs.chevron")
                        .resizable()
                        .frame(width: Size.iconS + 2, height: Size.iconS + 2)
                        .foregroundStyle(theme.palette.ink2)
                        .accessibilityHidden(true)
                }
            }
            .padding(Space.s16)
            .frame(minHeight: Size.touchIos)
            .contentShape(Rectangle())
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
