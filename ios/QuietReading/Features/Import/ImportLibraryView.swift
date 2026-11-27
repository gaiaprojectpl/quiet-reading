import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Flow 10 › B4 · Importing your library – from Home, Library or Settings (not only onboarding).
/// Runs in the background; "Keep using the app" closes this screen and a notification says when it's done.
struct ImportLibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(ImportSession.self) private var session
    @State private var showPicker = true
    @State private var started = false
    @State private var showError = false

    private var fraction: Double { session.total == 0 ? 0 : Double(session.done) / Double(session.total) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack { QsBackButton(title: "Cancel", action: { dismiss() }); Spacer() }
            Text("Importing your library")
                .font(theme.headline(30, relativeTo: .title))
                .foregroundStyle(theme.palette.ink)
                .accessibilityAddTraits(.isHeader)
            if started, session.phase != .failed {
                if !session.sourceName.isEmpty {
                    Text("\(session.total) books from \(session.sourceName)")
                        .font(.subheadline).foregroundStyle(theme.palette.ink2)
                }
                QsProgressBar(value: session.phase == .finished ? 1 : fraction)
                Text([String(localized: "\(session.done) of \(session.total)"), session.timeLeftText].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.palette.ink)
                    .contentTransition(.numericText())
                    .gentleAnimation(session.done)
                Text("You can leave this screen. We’ll let you know when your library is ready, and books appear as they arrive.")
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.ink2)
            } else {
                Text("Choose the CSV file you exported from Goodreads (My Books › Import and export) or StoryGraph (Manage account).")
                    .font(.subheadline)
                    .foregroundStyle(theme.palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if started, session.phase != .failed {
                    Button("Keep using the app") { dismiss() }
                        .buttonStyle(QsButtonStyle(priority: .secondary))
                } else {
                    Button("Choose a file") { showPicker = true }
                        .buttonStyle(QsButtonStyle(priority: .primary))
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, QsLayout.actionsAboveBottomLine)
            .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            session.start(fileURL: url, context: context)
            started = true
            showError = session.phase == .failed
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished, started { dismiss() }
        }
        .alert("We couldn’t read this file", isPresented: $showError) {
            Button("Help") { if let url = URL(string: "https://www.goodreads.com/review/import") { openURL(url) } }
            Button("Try again") { started = false; showPicker = true }
        } message: {
            Text("Make sure it’s the CSV from Goodreads › My Books › Import and export, or from StoryGraph › Manage account.")
        }
    }
}

/// Flow 10 › C4 · Something didn't load – generic fallback for any screen that fails to show its data.
struct DidNotLoadView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Space.s16) {
            EmptyStateView(icon: "qs.refresh", title: "This didn’t load",
                           message: "Your books are safe on this phone. Try again in a moment.")
            Button("Try again", action: retry)
                .buttonStyle(QsButtonStyle(priority: .outline))
        }
    }
}
