import SwiftUI

enum AppTab: Hashable {
    case home, library, add, stats, settings
}

/// Resolves the theme (system dark mode → Night, Increase Contrast → High contrast)
/// and hosts the one navigation used everywhere: Home · Library · Add · Stats · Settings.
struct RootView: View {
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var tab: AppTab = .home

    private var resolvedTheme: ThemeID {
        if contrast == .increased { return .highContrast }
        if colorScheme == .dark { return .night }
        return chosenTheme
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            Tab("Library", systemImage: "books.vertical", value: AppTab.library) { LibraryView() }
            Tab("Add", systemImage: "plus.circle.fill", value: AppTab.add) { AddBookView() }
            Tab("Stats", systemImage: "chart.bar", value: AppTab.stats) { StatsView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) { SettingsView() }
        }
        .tint(resolvedTheme.palette.accent)
        .environment(\.theme, resolvedTheme)
    }
}

#Preview {
    RootView()
}
