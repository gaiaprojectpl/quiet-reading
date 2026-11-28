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
    @AppStorage(ThemeStorage.forceHighContrast) private var forceHighContrast = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var importSession = ImportSession()
    @State private var notifications = NotificationCenterModel()
    @State private var connectivity = Connectivity()
    @State private var plus = PlusAccess()
    @State private var router = WidgetRouter()
    @State private var companion = CompanionStore()
    @Query private var allBooks: [Book]
    @AppStorage(ProfileKeys.goal) private var goal = 0
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ProfileKeys.lastImport) private var lastImport = 0.0
    @AppStorage(ProfileKeys.lastImportSource) private var lastImportSource = ""
    @Environment(\.modelContext) private var context
    /// The current book = the Reading-shelf book updated most recently (agreed rule).
    @Query(filter: #Predicate<Book> { $0.statusRaw == "reading" }, sort: \Book.lastUpdated, order: .reverse)
    private var reading: [Book]

    private var resolvedTheme: ThemeID {
        if contrast == .increased || forceHighContrast { return .highContrast }
        if colorScheme == .dark { return .night }
        // A Plus theme being tried on (Flow 5 › Live preview); a locked theme never sticks.
        if let preview = plus.previewTheme, !plus.isUnlocked { return preview }
        if chosenTheme.requiresPlus && !plus.isUnlocked { return .peachSage }
        return chosenTheme
    }

    /// Changes whenever something a widget shows changes.
    private var widgetSignature: String {
        let latest = allBooks.map(\.lastUpdated).max()?.timeIntervalSince1970 ?? 0
        let pages = allBooks.reduce(0) { $0 + $1.currentPage }
        let covers = allBooks.filter { $0.coverData != nil }.count
        let quotes = allBooks.reduce(0) { $0 + $1.quotes.count + $1.quotes.filter(\.showOnWidget).count * 1000 }
        return "\(allBooks.count)-\(latest)-\(pages)-\(covers)-\(quotes)-\(goal)-\(chosenTheme.rawValue)-\(forceHighContrast)-\(plus.isUnlocked)"
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
        // The daily reminder always names the current book and its latest page.
        .onChange(of: reading.first.map { "\($0.persistentModelID.hashValue)-\($0.currentPage)" }) {
            ReminderScheduler.refresh(book: reading.first)
        }
        // Widgets: keep them in step with the books, goal and theme; follow widget taps.
        .task(id: widgetSignature) {
            RecapScheduler.update(books: allBooks)
            WidgetSync.update(books: allBooks, goal: goal, theme: chosenTheme.requiresPlus && !plus.isUnlocked ? .peachSage : chosenTheme,
                              forceHighContrast: forceHighContrast, isPlus: plus.isUnlocked)
        }
        .onOpenURL { router.handle($0) }
        .onReceive(NotificationCenter.default.publisher(for: NotificationTaps.opened)) { note in
            if let url = note.object as? URL { router.handle(url) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in if phase == .active { router.checkPendingUpdate() } }
.fullScreenCover(isPresented: Bindable(plus).showPaywall) { PlusView().duoCover() }
        .environment(importSession)
        .environment(router)
        .environment(companion)
        .environment(connectivity)
        .environment(plus)
        .environment(notifications)
        #if DEBUG
        .modifier(DuoProbe())
        .task {
            let n = UserDefaults.standard.integer(forKey: "qsAstridEval")
            if n > 0 { await AstridEval.run(limit: n) }
        }
        #endif
        .tint(resolvedTheme.palette.accentInk)
        // Typed text and unstyled text use the theme's ink (never the system's white in dark mode).
        .foregroundStyle(resolvedTheme.palette.ink)
        .environment(\.theme, resolvedTheme)
    }
}

private struct MainTabs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.duoLayout) private var duo
    @Environment(\.theme) private var theme
    @Environment(PlusAccess.self) private var plus
    @Environment(WidgetRouter.self) private var router
    @Environment(CompanionStore.self) private var companion
    @State private var tab: AppTab = .home
    @State private var libraryShelf: ReadingStatus?
    @State private var showAdd = false
    @State private var showImport = false
    @State private var pendingAdd: AddMode?
    @State private var addFlow: AddFlowItem?

    struct AddFlowItem: Identifiable { let id = UUID(); let mode: AddMode }

    var body: some View {
        Group {
            if router.showSettings {
                // Flow 4 · Profile & Settings: opens over the current tab, tab bar stays; "‹ Home" (or the tab) goes back.
                SettingsView(onImport: { showImport = true }, onClose: { router.showSettings = false }, backTitle: tab.title)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            } else {
            switch tab {
            case .home: HomeView(onSeeAll: { libraryShelf = .toRead; tab = .library }, onAddBook: { showAdd = true }, onImport: { showImport = true })
            case .library: LibraryView(onAddBook: { showAdd = true }, onImport: { showImport = true }, requestedShelf: $libraryShelf)
            case .add: EmptyView() // Add is a sheet, never a tab
            case .stats: StatsView(onAddBook: { showAdd = true })
            case .explore: ExploreView()
            }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: Motion.base), value: router.showSettings)
        // Tapping a tab closes Profile & Settings.
        .onChange(of: tab) { router.showSettings = false }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if plus.previewTheme != nil && !plus.isUnlocked {
                PreviewBar().transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: Motion.base), value: plus.previewTheme)
        // Trying on a theme shows it where it matters most: Home.
        .onChange(of: plus.previewTheme) { _, new in if new != nil { router.showSettings = false; tab = .home } }
        // Widget taps land on Home (the book or its Update sheet), Add or Stats.
        .onChange(of: router.updateBookID) { _, id in if id != nil { tab = .home } }
        .onChange(of: router.openBookID) { _, id in if id != nil { tab = .home } }
        .onChange(of: router.openAdd) { _, open in if open { router.openAdd = false; showAdd = true } }
        .onChange(of: router.openStats) { _, open in if open { router.openStats = false; tab = .stats } }
        .onChange(of: router.openPlus) { _, open in if open { router.openPlus = false; plus.showPaywall = true } }
        .onChange(of: router.openBookInPlace) { _, b in if b != nil { tab = .home } }
        .onChange(of: router.updateCurrent) { _, on in if on { tab = .home } }
        .onChange(of: router.finishCurrent) { _, on in if on { tab = .home } }
        .onChange(of: router.openYear) { _, on in if on { tab = .stats } }
        .modifier(Navigation(duo: duo, tab: $tab, onAdd: { showAdd = true }, showAI: !companion.isOpen && !companion.buttonHidden))
        // Flow 12 · Reading companion: full screen on iPhone (and Duo closed / upright / tabletop),
        // the right-hand page when the Duo is open like a book.
        .fullScreenCover(isPresented: Binding(get: { companion.isOpen && duo.mode != .book },
                                              set: { if !$0 { companion.isOpen = false } })) {
            CompanionScreen().modifier(QsNotificationHost()).duoCover()
        }
        .overlay {
            if companion.isOpen && duo.mode == .book {
                // "Swap sides" (Astrid & privacy) mirrors the panes for left-handed use.
                let left = UserDefaults.standard.bool(forKey: CompanionKeys.leftPane)
                HStack(spacing: 0) {
                    if left {
                        CompanionScreen()
                            .frame(width: duo.fold.minX)
                            .clipShape(RoundedRectangle(cornerRadius: Space.s20, style: .continuous))
                            .shadow(color: theme.palette.scrim.opacity(0.08), radius: 12, x: 2, y: 0)
                            .transition(.move(edge: .leading))
                        Color.clear.allowsHitTesting(false)
                    } else {
                        Color.clear.frame(width: duo.fold.maxX).allowsHitTesting(false)
                        CompanionScreen()
                            .clipShape(RoundedRectangle(cornerRadius: Space.s20, style: .continuous))
                            .shadow(color: theme.palette.scrim.opacity(0.08), radius: 12, x: -2, y: 0)
                            .transition(.move(edge: .trailing))
                    }
                }
                .duoTopSpacing(duo)
            }
        }
        .animation(.easeOut(duration: Motion.base), value: companion.isOpen)
        .sheet(isPresented: $showAdd, onDismiss: {
            if let mode = pendingAdd { pendingAdd = nil; addFlow = AddFlowItem(mode: mode) }
        }) {
            AddBookView(onChoose: { pendingAdd = $0 })
        }
        .fullScreenCover(isPresented: $showImport) { ImportLibraryView().duoCover() }
        .fullScreenCover(item: $addFlow) { item in
            AddFlow(mode: item.mode)
                .modifier(QsNotificationHost())
                .duoCover()
        }
        #if DEBUG
        // Test builds only: `-qsOpen library` or `-qsOpen add` opens a tab or the Add sheet.
        .task {
            switch UserDefaults.standard.string(forKey: "qsOpen") {
            case "library": tab = .library
            case "stats": tab = .stats
            case "settings": router.showSettings = true
            case "explore": tab = .explore
            case "finish": router.finishCurrent = true
            case "add": showAdd = true
            case "addtype": addFlow = AddFlowItem(mode: .type)
            case "addcover": addFlow = AddFlowItem(mode: .cover)
            case "plus": plus.showPaywall = true
            case "companion": companion.isOpen = true
            case "preview": plus.previewTheme = .clayCream
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
        var showAI = true

        func body(content: Content) -> some View {
            if duo.usesRail {
                // Content stays in the safe area; the rail sits in the system column (the trailing safe area).
                content
                    .duoTopSpacing(duo)
                    .overlay(alignment: .bottomTrailing) {
                        // The content ends where the system column starts; shift the rail one column
                        // to the right so it sits inside the column, 24 pt above the bottom edge.
                        VStack(spacing: Space.s12) {
                            if showAI { CompanionButton(size: Size.button).transition(.scale.combined(with: .opacity)) }
                            QsTabRail(selection: $tab, onAdd: onAdd)
                        }
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
                        // Room under scrolling content so Astrid's button never hides the last card.
                        .contentMargins(.bottom, Size.button + Space.s24, for: .scrollContent)
                        // AI button: bottom-trailing, floating just above the tab bar.
                        .overlay(alignment: .bottomTrailing) {
                            if showAI {
                                CompanionButton()
                                    .padding(.trailing, Space.s20)
                                    .padding(.bottom, Space.s16)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    QsTabBar(selection: $tab, onAdd: onAdd)
                }
            }
        }
    }
}

/// Flow 5 › Live preview: "Previewing Clay & Cream · Get Plus", just above the navigation.
private struct PreviewBar: View {
    @Environment(\.theme) private var theme
    @Environment(PlusAccess.self) private var plus

    var body: some View {
        HStack(spacing: Space.s8) {
            Text("Previewing \(plus.previewTheme?.displayName ?? "")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.palette.onInverse)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Get Plus") { plus.showPaywall = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.palette.onAccent)
                .padding(.horizontal, Space.s12)
                .frame(minHeight: Size.buttonSmall - Space.s8)
                .background(theme.palette.accent, in: RoundedRectangle(cornerRadius: theme.radii.btn, style: .continuous))
                .frame(minHeight: Size.touchIos)
                .contentShape(Rectangle())
                .buttonStyle(QsPressStyle())
            Button { plus.previewTheme = nil } label: {
                Image("qs.close").resizable().frame(width: Size.iconS, height: Size.iconS)
                    .foregroundStyle(theme.palette.onInverse)
                    .frame(width: Size.touchIos, height: Size.touchIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End preview")
        }
        .padding(.leading, Space.s16)
        .padding(.trailing, Space.s4)
        .background(theme.palette.inverse, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .padding(.horizontal, Space.s16)
        .padding(.bottom, Space.s8)
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
