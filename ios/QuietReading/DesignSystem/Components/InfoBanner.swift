import SwiftUI

/// 🧱 Components › Banner · info. Inline, calm, never blocking.
struct InfoBanner: View {
    let message: LocalizedStringKey
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Size.iconM

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            Image("qs.info")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(theme.palette.ink)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.s12)
        .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
