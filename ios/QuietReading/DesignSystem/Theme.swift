import SwiftUI

nonisolated enum ThemeStorage {
    static let key = "themeID"
    /// In-app High contrast switch (App theme › Accessibility), on top of the system setting.
    static let forceHighContrast = "forceHighContrast"
}

nonisolated struct ThemeKey: EnvironmentKey {
    static let defaultValue: ThemeID = .peachSage
}

extension EnvironmentValues {
    /// The active, already-resolved theme. Read colours as `theme.palette.ink` etc.
    nonisolated var theme: ThemeID {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension ThemeID {
    /// Serif heading font of the theme (bundled in Resources/Fonts, registered by `QsFonts`).
    /// Scales with Dynamic Type.
    func headline(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(headFont.family, size: size, relativeTo: style).weight(headFont.weight)
    }
}
