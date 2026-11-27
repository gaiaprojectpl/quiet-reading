import SwiftUI
import SwiftData

nonisolated enum OnboardingStorage {
    static let key = "onboardingDone"
}

/// Resolves the theme (system dark mode → Night, Increase Contrast → High contrast),
/// shows Flow 1 on first launch, then the one navigation used everywhere.
/// On iPhone Duo the layout follows the system column and the fold (see `DuoLayout`).
struct RootView: View {
    @AppStorage(ThemeStorage.key) private var chosenTheme: ThemeID = .peachSage
    @AppStorage(OnboardingStorage.key) private var onboardingDone = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var importSession = ImportSession()
    @State private var notifications = NotificationCenterModel()
    @State private var connectivity = Connectivity()
    @State private var plus = PlusAccess()
    @AppStorage(ProfileKeys.lastImport) private var lastImport = 0.0
    @AppStorage(ProfileKeys.lastImportSource) private var lastImportSource = ""
    @Environment(\.modelContext) private var context

    private var resolvedTheme: ThemeID {
        if contrast == .increased { return .highContrast }
        if colorScheme == .dark { return .night }
        return chosenTheme
    }

    var body: some View {
        DuoLayoutReader { duo in
            Group {
                if onboardingDone {
                    MainTabs()
                } else {
                    // iOS already keeps content out of the Duo's system column (trailing safe area).
                    OnboardingFlow(onFinish: { onboardingDone = true })
                        .duoTopSpacing(duo)
                }
            }
            .background(resolvedTheme.palette.bg.ignoresSafeArea())
        }
        .modifier(QsNotificationHost())
        // Covers and details fill in by themselves: on launch and whenever the phone comes back online.
        .task(id: connectivity.isOnline) {
            if connectivity.isOnline { await CoverBackfill.run(context: context) }
        }
        .onChange(of: importSession.phase) { _, phase in
            if phase == .finished, importSession.total > 0 {
                lastImport = Date.now.timeIntervalSince1970
                lastImportSource = importSession.sourceName
                notifications.show(String(localized: "Your library is ready"),
                                   message: String(localized: "\(importSession.total) books"))
            }
        }
        .fullScreenCover(isPresented: Bindable(plus).showPaywall) { PlusView() }
        .environment(importSession)
        .environment(connectivity)
        .environment(plus)
        .environment(notifications)
        #if DEBUG
        .modifier(DuoProbe())
        #endif
        .tint(resolvedTheme.palette.accentInk)
        .environment(\.theme, resolvedTheme)
    }
}

private struct MainTabs: View {
    @Environment(\.duoLayout) private var duo
    @State private var tab: AppTab = .home
    @State private var showAdd = false
    @State private var showImport = false
    @State private var pendingAdd: AddMode?
    @State private var addFlow: AddFlowItem?

    struct AddFlowItem: Identifiable { let id = UUID(); let mode: AddMode }

    var body: some View {
        Group {
            switch tab {
            case .home: HomeView(onSeeAll: { tab = .library }, onAddBook: { showAdd = true }, onImport: { showImport = true })
            case .library: LibraryView(onAddBook: { showAdd = true }, onImport: { showImport = true })
            case .add: EmptyView() // Add is a sheet, never a tab
            case .stats: StatsView()
            case .settings: SettingsView(onImport: { showImport = true })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(Navigation(duo: duo, tab: $tab, onAdd: { showAdd = true }))
        .sheet(isPresented: $showAdd, onDismiss: {
            if let mode = pendingAdd { pendingAdd = nil; addFlow = AddFlowItem(mode: mode) }
        }) {
            AddBookView(onChoose: { pendingAdd = $0 })
        }
        .fullScreenCover(isPresented: $showImport) { ImportLibraryView() }
        .fullScreenCover(item: $addFlow) { item in
            AddFlow(mode: item.mode)
                .modifier(QsNotificationHost())
        }
        #if DEBUG
        // Test builds only: `-qsOpen library` or `-qsOpen add` opens a tab or the Add sheet.
        .task {
            switch UserDefaults.standard.string(forKey: "qsOpen") {
            case "library": tab = .library
            case "settings", "stats": tab = UserDefaults.standard.string(forKey: "qsOpen") == "stats" ? .stats : .settings
            case "add": showAdd = true
            case "addtype": addFlow = AddFlowItem(mode: .type)
            case "addcover": addFlow = AddFlowItem(mode: .cover)
            default: break
            }
        }
        #endif
    }

    /// Bottom tab bar on iPhone and in tabletop; the vertical rail in the system column on Duo.
    private struct Navigation: ViewModifier {
        let duo: DuoLayout
        @Binding var tab: AppTab
        let onAdd: () -> Void

        func body(content: Content) -> some View {
            if duo.usesRail {
                // Content stays in the safe area; the rail sits in the system column (the trailing safe area).
                content
                    .duoTopSpacing(duo)
                    .overlay(alignment: .bottomTrailing) {
                        // The content ends where the system column starts; shift the rail one column
                        // to the right so it sits inside the column, 24 pt above the bottom edge.
                        QsTabRail(selection: $tab, onAdd: onAdd)
                            .frame(width: duo.column)
                            .offset(x: duo.column)
                            .padding(.bottom, Space.s24)
                            .ignoresSafeArea(edges: .bottom)
                    }
            } else {
                // Stacked (not an inset) so buttons pinned to the bottom of a screen sit above the bar.
                VStack(spacing: 0) {
                    content
                        .duoTopSpacing(duo)
                        .frame(maxHeight: .infinity)
                    QsTabBar(selection: $tab, onAdd: onAdd)
                }
            }
        }
    }
}

private extension View {
    /// On Duo the clock lives in the side column, so the top safe area is 0.
    /// Give titles the same room as below an iPhone status bar so they don't hug the corner.
    func duoTopSpacing(_ duo: DuoLayout) -> some View {
        padding(.top, duo.topSpacing)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Book.self, inMemory: true)
}
