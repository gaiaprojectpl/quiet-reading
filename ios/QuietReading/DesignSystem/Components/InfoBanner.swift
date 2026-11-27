import SwiftUI

/// 🧱 Components › Banner (info / error). Inline, calm, never blocking.
struct InfoBanner: View {
    enum Kind { case info, error }
    let message: LocalizedStringKey
    var kind: Kind = .info
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Size.iconM

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            Image(kind == .error ? "qs.alert" : "qs.info")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(kind == .error ? theme.palette.error : theme.palette.ink)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.s12)
        .background(kind == .error ? theme.palette.errorSoft : theme.palette.soft2,
                    in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
