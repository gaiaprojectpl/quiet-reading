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
///
/// Buttons go in `actions` (button placement rules, Figma 110:14182):
/// - iPhone (bottom tab bar): in the content, under the message – never stacked on the tab bar.
/// - iPhone Duo: pinned to the bottom in every posture, 24 pt above the bottom line
///   (screen edge, or the tab bar when the Duo is upright or in tabletop).
struct ScreenScaffold<Content: View, Actions: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions
    var hasActions = true
    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo

    private var pinActions: Bool { hasActions && duo.mode != .phone }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s16) {
                    ScreenTitle(title: title)
                        .padding(.bottom, Space.s8)
                    content
                    if hasActions && !pinActions {
                        VStack(spacing: Space.s12) { actions }
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s40)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pinActions {
                    VStack(spacing: Space.s12) { actions }
                        .padding(.horizontal, Space.s20)
                        .padding(.top, Space.s12)
                        .padding(.bottom, duo.actionsBottom)
                        .background(theme.palette.bg)
                }
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension ScreenScaffold where Actions == EmptyView {
    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title: title, content: content, actions: { EmptyView() }, hasActions: false)
    }
}
