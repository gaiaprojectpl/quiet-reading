import SwiftUI

/// Large screen title in the theme's serif heading font. Marked as a heading for VoiceOver.
struct ScreenTitle: View {
    let title: LocalizedStringKey
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(theme.headline(34, relativeTo: .largeTitle))
            .foregroundStyle(theme.palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Shared screen shell: themed background, 20 pt side margins, serif large title.
/// The system navigation bar is hidden because it can't use the per-theme heading font.
struct ScreenScaffold<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s16) {
                    ScreenTitle(title: title)
                        .padding(.bottom, Space.s8)
                    content
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s40)
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
