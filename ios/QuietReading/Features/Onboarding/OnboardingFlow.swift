import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Flow 1 · First launch & import: Landing → Bring your books → Importing → Add your widget → Home.
enum OnboardingStep: Hashable {
    case sources, importing, widget, notReady
}

struct OnboardingFlow: View {
    let onFinish: () -> Void
    @State private var path: [OnboardingStep] = []
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack(path: $path) {
            LandingView(
                onGetStarted: { path.append(.sources) },
                onHaveAccount: { path.append(.notReady) }
            )
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .sources:
                    ChooseSourceView(
                        onImportStarted: { path.append(.importing) },
                        onStartFresh: { path.append(.widget) },
                        onNotReady: { path.append(.notReady) }
                    )
                case .importing:
                    ImportProgressView(onContinue: {
                        if path.last == .importing { path.append(.widget) }
                    })
                case .widget:
                    WidgetGuideView(onDone: onFinish)
                case .notReady:
                    NotReadyView(onBack: { path.removeLast() })
                }
            }
        }
        .tint(theme.palette.accentInk)
        #if DEBUG
        .task { debugJump() }
        #endif
    }

    #if DEBUG
    @Environment(\.modelContext) private var context
    @Environment(ImportSession.self) private var session

    /// Test builds only: open a step directly, e.g. launch with `-qsStep sources`,
    /// or `-qsImport /path/to/export.csv` to run an import without the file picker.
    private func debugJump() {
        let defaults = UserDefaults.standard
        if let file = defaults.string(forKey: "qsImport") {
            session.start(fileURL: URL(fileURLWithPath: file), context: context)
            path = [.sources, .importing]
        } else if let step = defaults.string(forKey: "qsStep") {
            switch step {
            case "sources": path = [.sources]
            case "widget": path = [.sources, .widget]
            case "notReady": path = [.notReady]
            default: break
            }
        }
    }
    #endif
}

/// Shared shell for onboarding screens: bg, 20 pt sides, content scrolls with large text.
/// Buttons sit in `actions`, pinned to the bottom so they're within thumb reach.
struct OnboardingPage<Content: View, Actions: View>: View {
    var spacing: CGFloat = Space.s20
    var showsBack = true
    var hasActions = true
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions
    @Environment(\.theme) private var theme
    @Environment(\.duoLayout) private var duo

    var body: some View {
        if duo.mode == .book {
            // Duo open: a calm illustration on the left page, the screen itself on the right page.
            HStack(spacing: duo.fold.width) {
                DuoIllustrationPage()
                    .frame(width: duo.fold.minX)
                page
            }
            .background(theme.palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        } else {
            page
        }
    }

    /// Button placement rules (Figma, 27 Nov): bottom of the action group 16 pt above the safe area
    /// (50 pt from the edge on iPhone). The Duo has no home indicator area, so keep 48 pt there.
    private var actionsBottom: CGFloat { duo.mode == .phone ? Space.s16 : Space.s48 }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) { content }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.palette.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasActions {
                VStack(spacing: Space.s12) { actions }
                    .padding(.horizontal, Space.s20)
                    .padding(.top, Space.s12)
                    .padding(.bottom, actionsBottom)
                    .background(theme.palette.bg)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsBack {
                HStack { QsBackButton(); Spacer() }
                    .padding(.horizontal, Space.s12)
                    .background(theme.palette.bg)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension OnboardingPage where Actions == EmptyView {
    init(spacing: CGFloat = Space.s20, showsBack: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing, showsBack: showsBack, hasActions: false, content: content, actions: { EmptyView() })
    }
}

/// Left page on the open Duo: the cover fan on a soft card (Figma Flow 6b › Onboarding).
struct DuoIllustrationPage: View {
    @Environment(\.theme) private var theme

    var body: some View {
        CoverFan()
            .padding(Space.s20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.soft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .padding(Space.s20)
            .accessibilityHidden(true)
    }
}

/// Screen title in the heading font (30 pt in Figma).
struct OnboardingTitle: View {
    let text: LocalizedStringKey
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(theme.headline(30, relativeTo: .title))
            .foregroundStyle(theme.palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Step 1 · Landing

struct LandingView: View {
    let onGetStarted: () -> Void
    let onHaveAccount: () -> Void
    @Environment(\.theme) private var theme

    @Environment(\.duoLayout) private var duo

    var body: some View {
        if duo.mode == .book {
            bookLayout
        } else {
            singleLayout
        }
    }

    /// Duo open (Figma Flow 6b › Onboarding): illustration on the left page, words and buttons on the right.
    private var bookLayout: some View {
        HStack(spacing: duo.fold.width) {
            DuoIllustrationPage()
                .frame(width: duo.fold.minX)
            VStack(alignment: .leading, spacing: Space.s16) {
                QsLogo()
                Spacer(minLength: Space.s16)
                Text("Your reading life, quietly on your home screen.")
                    .font(theme.headline(30, relativeTo: .title))
                    .foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Add a book with one photo. Update in one tap. No streaks, no noise.")
                    .font(.body)
                    .foregroundStyle(theme.palette.ink2)
                Spacer(minLength: Space.s16)
                actions
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s20)
            .padding(.bottom, Space.s48) // button placement rules: clear of the edge on Duo
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var actions: some View {
        Button("Get started", action: onGetStarted)
            .buttonStyle(QsButtonStyle(kind: .primary))
        Button("I already have an account", action: onHaveAccount)
            .buttonStyle(QsButtonStyle(kind: .secondary))
        Text("Free to use · Plus themes are optional")
            .font(.footnote)
            .foregroundStyle(theme.palette.ink2)
            .frame(maxWidth: .infinity)
    }

    private var singleLayout: some View {
        OnboardingPage(spacing: Space.s16, showsBack: false) {
            QsLogo()
            CoverFan()
            Text("Your reading life, quietly on your home screen.")
                .font(theme.headline(30, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Add a book with one photo. Update in one tap. No streaks, no noise.")
                .font(.body)
                .foregroundStyle(theme.palette.ink2)
        } actions: {
            actions
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The four sample covers fanned over a soft circle (Figma: Landing › Covers, 353 × 300).
/// Offsets and angles are illustration geometry taken from the design.
struct CoverFan: View {
    @Environment(\.theme) private var theme
    private let covers: [(name: String, x: CGFloat, y: CGFloat, angle: Double)] = [
        ("cover.quiet-orchard", -115, 12, 8),
        ("cover.salt-pages", -18, -36, -5),
        ("cover.north-library", 52, -4, 3),
        ("cover.winter-tea", 126, -46, -9),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.palette.soft)
                .frame(width: 250, height: 250)
            ForEach(covers, id: \.name) { cover in
                BookCover(source: .asset(cover.name), width: 96)
                    .rotationEffect(.degrees(cover.angle))
                    .offset(x: cover.x, y: cover.y)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .accessibilityHidden(true)
    }
}

// MARK: - Step 2 · Bring your books

struct ChooseSourceView: View {
    let onImportStarted: () -> Void
    let onStartFresh: () -> Void
    let onNotReady: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(ImportSession.self) private var session
    @State private var showImporter = false

    var body: some View {
        OnboardingPage {
            OnboardingTitle(text: "Bring your books")
            Text("Choose where your reading lives today. You can add more later.")
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink2)

            VStack(spacing: 0) {
                SourceRow(icon: "qs.link", title: "Goodreads profile link",
                          subtitle: "Reads your shelves · public profiles", action: onNotReady)
                divider
                SourceRow(icon: "qs.file", title: "Goodreads CSV file",
                          subtitle: "Full history from a Goodreads export") { showImporter = true }
                divider
                SourceRow(icon: "qs.file", title: "StoryGraph CSV file",
                          subtitle: "From StoryGraph › Manage account") { showImporter = true }
                divider
                SourceRow(icon: "qs.library", title: "Hardcover account",
                          subtitle: "Live sync with your API token", action: onNotReady)
                divider
                SourceRow(icon: "qs.plus", title: "Start fresh",
                          subtitle: "Add books by photo or search", action: onStartFresh)
            }
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                .strokeBorder(theme.palette.line, lineWidth: 0.75))

            InfoBanner(message: "We never ask for your Goodreads password.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            session.start(fileURL: url, context: context)
            onImportStarted()
        }
    }

    private var divider: some View {
        theme.palette.line.frame(height: Size.stroke)
    }
}

private struct SourceRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var tile = Space.s40
    @ScaledMetric(relativeTo: .body) private var glyph = Size.iconM + 2

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s16) {
                Image(icon)
                    .resizable()
                    .frame(width: glyph, height: glyph)
                    .foregroundStyle(theme.palette.accentInk)
                    .frame(width: tile, height: tile)
                    .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(theme.palette.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(theme.palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("qs.chevron")
                    .resizable()
                    .frame(width: Size.iconS + 2, height: Size.iconS + 2)
                    .foregroundStyle(theme.palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(Space.s16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 3 · Importing your books

struct ImportProgressView: View {
    let onContinue: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(ImportSession.self) private var session
    @State private var showImporter = false
    @State private var showError = false

    private var fraction: Double {
        session.total == 0 ? 0 : Double(session.done) / Double(session.total)
    }

    var body: some View {
        OnboardingPage {
            OnboardingTitle(text: "Importing your books")
            Text("\(session.done) of \(session.total)")
                .font(theme.headline(40, relativeTo: .largeTitle))
                .foregroundStyle(theme.palette.accentInk)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(session.done) of \(session.total) books matched")
            QsProgressBar(value: fraction)
            Text("Matching editions and covers…")
                .font(.subheadline)
                .foregroundStyle(theme.palette.ink2)
            if !session.recentCovers.isEmpty {
                HStack(spacing: Space.s20) {
                    ForEach(Array(session.recentCovers.enumerated()), id: \.offset) { _, data in
                        BookCover(source: .data(data), width: Size.coverM)
                    }
                }
            }
            if session.missingCovers > 0 {
                InfoBanner(message: "\(session.missingCovers) books have no cover yet. You can add your own photo later.")
            }
        } actions: {
            Button("Continue in the background", action: onContinue)
                .buttonStyle(QsButtonStyle(kind: .secondary))
        }
        .onAppear { showError = session.phase == .failed }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { onContinue() }
            showError = phase == .failed
        }
        .alert("We couldn’t read this file", isPresented: $showError) {
            Button("Help") {
                if let url = URL(string: "https://www.goodreads.com/review/import") { openURL(url) }
            }
            Button("Try again") { showImporter = true }
        } message: {
            Text("Make sure it’s the CSV from Goodreads › My Books › Import and export, or from StoryGraph › Manage account.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            session.start(fileURL: url, context: context)
        }
    }
}

// MARK: - Step 4 · Add your reading widget

struct WidgetGuideView: View {
    let onDone: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        OnboardingPage {
            OnboardingTitle(text: "Add your reading widget")
            WidgetPreview()
                .frame(maxWidth: .infinity)
                .padding(Space.s20)
                .background(theme.palette.soft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            Step(number: 1, text: "Touch and hold an empty spot on your Home Screen")
            Step(number: 2, text: "Tap Edit, then Add Widget")
            Step(number: 3, text: "Search “Quiet Reading” and pick a size")
        } actions: {
            Button("Done", action: onDone)
                .buttonStyle(QsButtonStyle(kind: .primary))
            Button("Remind me later", action: onDone)
                .buttonStyle(QsButtonStyle(kind: .text))
        }
    }

    private struct Step: View {
        let number: Int
        let text: LocalizedStringKey
        @Environment(\.theme) private var theme
        @ScaledMetric(relativeTo: .subheadline) private var badge = Size.iconL + Space.s4

        var body: some View {
            HStack(spacing: Space.s12) {
                Text("\(number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.palette.onAccent)
                    .frame(width: badge, height: badge)
                    .background(theme.palette.accent, in: Circle())
                    .accessibilityHidden(true)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Step \(number). ") + Text(text))
        }
    }
}

/// Small widget mock-up (Figma: Widget · small, 158 × 158). Illustration only.
private struct WidgetPreview: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            HStack(spacing: Space.s8) {
                BookCover(source: .asset("cover.quiet-orchard"), width: Space.s40)
                Text("Update")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.palette.onAccent)
                    .padding(.horizontal, Space.s12)
                    .frame(height: 36)
                    .background(theme.palette.accent, in: Capsule())
            }
            Text("The Quiet Orchard")
                .font(theme.headline(13, relativeTo: .footnote))
                .foregroundStyle(theme.palette.ink)
            QsProgressBar(value: 0.46)
            Text("p. 142 · 46%")
                .font(.caption2)
                .foregroundStyle(theme.palette.ink2)
        }
        .padding(Space.s12)
        .frame(width: 158, height: 158, alignment: .topLeading)
        .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.palette.line, lineWidth: 0.75))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example of the reading widget, showing your current book with an Update button")
    }
}

// MARK: - Not available yet

/// For sources and sign-in that come in a later build.
struct NotReadyView: View {
    let onBack: () -> Void

    var body: some View {
        OnboardingPage {
            EmptyStateView(
                icon: "qs.info",
                title: "This comes in a later update",
                message: "For now you can import a CSV file or start fresh."
            )
        } actions: {
            Button("Go back", action: onBack)
                .buttonStyle(QsButtonStyle(kind: .primary))
        }
    }
}

#Preview {
    OnboardingFlow(onFinish: {})
        .environment(ImportSession())
        .modelContainer(for: Book.self, inMemory: true)
}
