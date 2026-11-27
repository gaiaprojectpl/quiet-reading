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

/// 🧱 Components › Nav bar. One navigation everywhere: Home · Library · Add · Stats · Settings.
/// Selected = soft pill behind the icon; Add = accent circle.
struct QsTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Item(tab: tab, isSelected: selection == tab) { selection = tab }
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
    }

    private struct Item: View {
        let tab: AppTab
        let isSelected: Bool
        let action: () -> Void
        @Environment(\.theme) private var theme
        @ScaledMetric(relativeTo: .caption) private var icon = Size.iconL

        var body: some View {
            Button(action: action) {
                VStack(spacing: Space.s4) {
                    indicator
                    Text(tab.title)
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected || tab == .add ? theme.palette.ink : theme.palette.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(Space.s4)
                .frame(maxWidth: .infinity, minHeight: Size.touchIos)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(tab.title))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }

        @ViewBuilder private var indicator: some View {
            let image = Image(tab.icon).resizable().frame(width: icon, height: icon)
            if tab == .add {
                image
                    .foregroundStyle(theme.palette.onAccent)
                    .frame(width: Space.s48, height: Space.s40)
                    .background(theme.palette.accent, in: Capsule())
            } else {
                image
                    .foregroundStyle(isSelected ? theme.palette.ink : theme.palette.ink2)
                    .frame(width: Space.s64, height: Space.s32)
                    .background(isSelected ? theme.palette.soft : .clear, in: Capsule())
            }
        }
    }
}
