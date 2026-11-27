import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home, library, add, stats, settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .add: "Add"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "qs.home"
        case .library: "qs.library"
        case .add: "qs.add"
        case .stats: "qs.stats"
        case .settings: "qs.settings"
        }
    }
}

/// 🧱 Components › Nav bar (Figma 47:216). One navigation everywhere: Home · Library · Add · Stats · Settings.
/// Nav item states: Enabled, Pressed (soft2 pill), Active (soft pill + semibold label),
/// Active pressed (tintStrong pill). Add = accent circle that opens the Add sheet – never active.
/// Light haptic when switching. VoiceOver: "Library, tab, 2 of 5, selected".
struct QsTabBar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                Button {
                    if tab == .add { onAdd() } else { selection = tab }
                } label: {
                    EmptyView()
                }
                .buttonStyle(NavItemStyle(tab: tab, isActive: tab != .add && selection == tab))
                .accessibilityLabel(Text(tab.title))
                .accessibilityValue(tab == .add ? Text("") : Text("Tab \(index + 1) of \(AppTab.allCases.count)"))
                .accessibilityAddTraits(tab != .add && selection == tab ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, Space.s12)
        .padding(.top, Space.s8)
        .padding(.bottom, Space.s4)
        .background {
            theme.palette.surface
                .overlay(alignment: .top) { theme.palette.line.frame(height: Size.stroke) }
                .ignoresSafeArea(edges: .bottom)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct NavItemStyle: ButtonStyle {
    let tab: AppTab
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        NavItem(tab: tab, isActive: isActive, isPressed: configuration.isPressed)
    }
}

private struct NavItem: View {
    let tab: AppTab
    let isActive: Bool
    let isPressed: Bool
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .caption) private var icon = Size.iconL

    private var pill: Color {
        switch (isActive, isPressed) {
        case (true, true): theme.palette.tintStrong
        case (true, false): theme.palette.soft
        case (false, true): theme.palette.soft2
        case (false, false): .clear
        }
    }

    var body: some View {
        VStack(spacing: Space.s4) {
            let image = Image(tab.icon).resizable().frame(width: icon, height: icon)
            if tab == .add {
                image
                    .foregroundStyle(theme.palette.onAccent)
                    .frame(width: Space.s48, height: Space.s40)
                    .background(isPressed ? theme.palette.accentPressed : theme.palette.accent, in: Capsule())
            } else {
                image
                    .foregroundStyle(isActive ? theme.palette.ink : theme.palette.ink2)
                    .frame(width: Space.s64, height: Space.s32)
                    .background(pill, in: Capsule())
            }
            Text(tab.title)
                .font(.caption.weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive || tab == .add ? theme.palette.ink : theme.palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, minHeight: Size.touchIos)
        .contentShape(Rectangle())
    }
}
