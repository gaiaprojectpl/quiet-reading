import SwiftUI

/// 🧱 Components › Empty state. Title = what is true now; message = one calm sentence.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.s12) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(theme.palette.accentInk)
                .frame(width: 80, height: 80)
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
