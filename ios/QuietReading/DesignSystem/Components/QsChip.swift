import SwiftUI

/// 🧱 Components › Chip. Selected: soft2 fill, 1.5 pt accent border and a check. Unselected: line border.
struct QsChip: View {
    let title: String
    var isSelected = false
    /// Optional leading icon (e.g. the shelf chip's bookmark). Replaces the selected check.
    var icon: String? = nil
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s8) {
                if let icon = icon ?? (isSelected ? "qs.check" : nil) {
                    Image(icon)
                        .resizable()
                        .frame(width: Size.iconS, height: Size.iconS)
                        .foregroundStyle(theme.palette.accentInk)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.palette.ink)
            }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s8)
            .frame(minHeight: Size.touchIos)
            .background(isSelected ? theme.palette.soft2 : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? theme.palette.accent : theme.palette.line,
                                            lineWidth: isSelected ? 1.5 : Size.stroke))
            .contentShape(Capsule())
        }
        .buttonStyle(QsPressStyle())
        .gentleAnimation(isSelected, duration: Motion.fast)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Lays children out left to right and wraps onto new lines (chips, tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.s8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: min(width, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
