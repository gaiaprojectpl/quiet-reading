import SwiftUI

/// 🧱 Components › Logo: bookmark "q" on an accent tile + the wordmark in the heading font.
struct QsLogo: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .title2) private var tile = Space.s40 - 1.6 // 38.4 in Figma

    var body: some View {
        HStack(spacing: Space.s12) {
            Image("qs.logo")
                .resizable()
                .foregroundStyle(theme.palette.bg)
                .frame(width: tile, height: tile)
                .background(theme.palette.accent, in: RoundedRectangle(cornerRadius: tile / 4, style: .continuous))
            Text("Quiet Reading")
                .font(theme.headline(24, relativeTo: .title2))
                .foregroundStyle(theme.palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quiet Reading")
        .accessibilityAddTraits(.isHeader)
    }
}
