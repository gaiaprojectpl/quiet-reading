import CoreFoundation

/// Layout rules shared by every screen.
nonisolated enum QsLayout {
    /// Buttons sit this far above the bottom line: the screen edge, the home-indicator area,
    /// the tab bar or the keyboard – whichever is at the bottom. (Kaja, 27 Nov 2026)
    static let actionsAboveBottomLine: CGFloat = Space.s24
}
