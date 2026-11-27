import SwiftUI

/// Flow 5 › Theme card: a tiny "Reading now" screen drawn in that theme's own colours,
/// radii and heading font, so readers see the theme before they choose it.
/// Used on App theme (2 across) and on the Plus screen (3 across).
struct ThemePreviewCard: View {
    let id: ThemeID
    var title: String
    var isSelected = false
    var isLocked = false
    var compact = false

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .caption) private var cover = Space.s32 + Space.s4

    private var p: Palette { id.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Space.s8 : Space.s12) {
            HStack(alignment: .top, spacing: Space.s8) {
                Image("cover.winter-tea")
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(width: cover, height: cover * 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: max(id.radii.cover / 2, 2), style: .continuous))
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text("Reading now")
                        .font(id.headline(12, relativeTo: .caption))
                        .foregroundStyle(p.ink)
                        .lineLimit(compact ? 3 : 1)
                    Capsule().fill(p.accent).frame(height: Space.s6)
                    Capsule().fill(p.accent.opacity(0.75)).frame(height: Space.s6)
                    Capsule().fill(p.soft2).frame(height: Space.s6)
                }
            }
            HStack(spacing: Space.s4) {
                ForEach(Array([p.bg, p.soft, p.soft2, p.accent, p.ink].enumerated()), id: \.offset) { _, color in
                    Circle().fill(color)
                        .overlay(Circle().strokeBorder(p.line, lineWidth: Size.stroke))
                        .frame(width: Space.s8 + Space.s2, height: Space.s8 + Space.s2)
                }
            }
            HStack(spacing: Space.s4) {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(p.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isLocked {
                    Image("qs.lock").resizable().frame(width: Size.iconS, height: Size.iconS)
                        .foregroundStyle(p.ink2)
                } else if isSelected {
                    Image("qs.check").resizable().frame(width: Size.iconS, height: Size.iconS)
                        .foregroundStyle(p.accentInk)
                }
            }
        }
        .padding(compact ? Space.s8 : Space.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .strokeBorder(isSelected ? theme.palette.accent : theme.palette.line,
                              lineWidth: isSelected ? Size.focusRing : Size.stroke)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isLocked ? String(localized: "Plus, locked") : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    HStack {
        ThemePreviewCard(id: .peachSage, title: "Peach & Sage", isSelected: true)
        ThemePreviewCard(id: .clayCream, title: "Clay & Cream", isLocked: true)
    }
    .padding()
}
