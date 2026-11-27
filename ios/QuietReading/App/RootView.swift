import SwiftUI
import SwiftData

nonisolated enum OnboardingStorage {
    static let key = "onboardingDone"
}

/// Resolves the theme (system dark mode → Night, Increase Contrast → High contrast),
/// shows Flow 1 on first launch, then the one navigation used everywhere.
struct RootView: View {
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @AppStorage(OnboardingStorage.key) private var onboardingDone = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var importSession = ImportSession()

    private var resolvedTheme: ThemeID {
        if contrast == .increased { return .highContrast }
        if colorScheme == .dark { return .night }
        return chosenTheme
    }

    var body: some View {
        Group {
            if onboardingDone {
                MainTabs()
            } else {
                OnboardingFlow(onFinish: { onboardingDone = true })
            }
        }
        .environment(importSession)
        #if DEBUG
        .modifier(DuoProbe())
        #endif
        .tint(resolvedTheme.palette.accentInk)
        .environment(\.theme, resolvedTheme)
    }
}

private struct MainTabs: View {
    @State private var tab: AppTab = .home
    @State private var showAdd = false

    var body: some View {
        Group {
            switch tab {
            case .home: HomeView(onSeeAll: { tab = .library }, onAddBook: { showAdd = true })
            case .library: LibraryView()
            case .add: EmptyView() // Add is a sheet, never a tab
            case .stats: StatsView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QsTabBar(selection: $tab, onAdd: { showAdd = true })
        }
        .sheet(isPresented: $showAdd) {
            AddBookView()
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Book.self, inMemory: true)
}
