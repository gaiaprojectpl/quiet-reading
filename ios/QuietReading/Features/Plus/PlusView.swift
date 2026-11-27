import SwiftUI

/// Flow 5 · Quiet Reading Plus. (Replaced by the full paywall and StoreKit in the payment step.)
struct PlusView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack { QsBackButton(title: "Close", action: { dismiss() }); Spacer() }
            Text("Quiet Reading Plus").font(theme.headline(30, relativeTo: .title)).foregroundStyle(theme.palette.ink)
            Text("Three more themes and app icons. One payment, no subscription.")
                .font(.subheadline).foregroundStyle(theme.palette.ink2)
            Spacer()
        }
        .padding(.horizontal, Space.s20)
        .background(theme.palette.bg.ignoresSafeArea())
    }
}
