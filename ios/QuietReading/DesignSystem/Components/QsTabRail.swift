import SwiftUI

/// 🧱 Components › Nav bar · Duo (vertical, right) (Figma 131:1705).
/// Lives in the 84 pt right system column, 60 pt wide, bottom-aligned 24 pt above the edge.
/// 52 pt items with 24 pt icons (enlarged 27 Nov for easier reach). VoiceOver reads full labels.
struct QsTabRail: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.s4) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                Button {
                    if tab == .add { onAdd() } else { selection = tab }
                } label: {
                    EmptyView()
                }
                .buttonStyle(RailItemStyle(tab: tab, isActive: tab != .add && selection == tab))
                .accessibilityLabel(Text(tab.title))
                .accessibilityValue(tab == .add ? Text("") : Text("Tab \(index + 1) of \(AppTab.allCases.count)"))
                .accessibilityAddTraits(tab != .add && selection == tab ? [.isSelected] : [])
            }
        }
        .padding(Space.s4)
        .background(theme.palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.palette.line, lineWidth: Size.stroke))
        .shadow(color: theme.palette.scrim.opacity(0.06), radius: 2, x: 0, y: 1) // Elevation/1 · card
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct RailItemStyle: ButtonStyle {
    let tab: AppTab
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        RailItem(tab: tab, isActive: isActive, isPressed: configuration.isPressed)
    }
}

private struct RailItem: View {
    let tab: AppTab
    let isActive: Bool
    let isPressed: Bool
    @Environment(\.theme) private var theme

    private var fill: Color {
        if tab == .add { return isPressed ? theme.palette.accentPressed : theme.palette.accent }
        switch (isActive, isPressed) {
        case (true, true): return theme.palette.tintStrong
        case (true, false): return theme.palette.soft
        case (false, true): return theme.palette.soft2
        case (false, false): return .clear
        }
    }

    var body: some View {
        Image(tab.icon)
            .resizable()
            .frame(width: Size.iconL, height: Size.iconL)
            .foregroundStyle(tab == .add ? theme.palette.onAccent : (isActive ? theme.palette.ink : theme.palette.ink2))
            .frame(width: Self.item, height: Self.item)
            .background(fill, in: Circle())
            .contentShape(Circle())
    }

    /// 52 pt circles: comfortably above the 44 pt minimum and filling the 84 pt column.
    private static let item: CGFloat = Space.s48 + Space.s4
}
