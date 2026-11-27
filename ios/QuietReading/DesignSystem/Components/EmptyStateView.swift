import SwiftUI

/// 🧱 Components › Empty state. Title = what is true now; message = one calm sentence.
struct EmptyStateView: View {
    /// Name of a `qs.*` icon in Assets.xcassets (Tabler outline, stroke 1.5).
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .title) private var iconSize = Size.iconL * 1.5
    @ScaledMetric(relativeTo: .title) private var circleSize = Size.coverM + Space.s8

    var body: some View {
        VStack(spacing: Space.s12) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(theme.palette.accentInk)
                .frame(width: circleSize, height: circleSize)
                .background(theme.palette.soft2, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(theme.headline(22, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Space.s32)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
