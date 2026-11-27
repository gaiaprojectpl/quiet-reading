import SwiftUI
import SwiftData

@main
struct QuietReadingApp: App {
    init() {
        QsFonts.register()
        NotificationTaps.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            LaunchContainer()
        }
        .modelContainer(for: [Book.self, ReadingSession.self, Quote.self])
    }
}

/// Plays the splash once per launch from zero, then reveals the app: it rises 12 pt and fades in.
private struct LaunchContainer: View {
    @State private var splashDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RootView()
                .opacity(splashDone ? 1 : 0)
                .offset(y: splashDone || reduceMotion ? 0 : Space.s12)
            if !splashDone {
                SplashView {
                    withAnimation(.easeOut(duration: Motion.slow)) { splashDone = true }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
