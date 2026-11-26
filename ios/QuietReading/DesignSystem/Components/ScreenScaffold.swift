import SwiftUI

/// Shared screen shell: themed background, 20 pt side margins, large title.
struct ScreenScaffold<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s16) { content }
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s24)
                    .padding(.bottom, Space.s40)
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .navigationTitle(title)
        }
    }
}
