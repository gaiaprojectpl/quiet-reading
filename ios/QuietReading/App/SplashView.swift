import SwiftUI

/// Flow 11 · Splash (launch animation), shown when the app starts from zero.
/// Frame 1 is the static launch screen (sage, cream "q" with its ribbon tucked in), so there is no jump.
/// 0–400 ms the bookmark ribbon drops (spring, gentle overshoot) · 400–750 ms "Quiet Reading" fades in
/// and rises 8 pt while the q lifts · 750–1100 ms sage fades into the app. Never waits for anything;
/// any tap skips. Reduce Motion: frame 1 cross-fades to the app in 200 ms.
/// Brand colours are Peach & Sage on purpose: the launch screen can't know the reader's theme.
struct SplashView: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ribbonDown = false
    @State private var nameShown = false
    @State private var fading = false

    private let brand = ThemeID.peachSage.palette
    /// Same size as the launch screen image (LaunchLogo, 192 pt artboard; the q is ~57 pt wide).
    private let logo: CGFloat = 192

    var body: some View {
        ZStack {
            brand.accent.ignoresSafeArea()
            ZStack {
                Image("qs.logo.bowl").resizable().foregroundStyle(brand.bg)
                Ribbon(progress: ribbonDown ? 1 : 0).fill(brand.bg)
            }
            .frame(width: logo, height: logo)
            // The q lifts a little to make room for the name.
            .offset(y: nameShown ? -Space.s24 : 0)
            Text("Quiet Reading")
                .font(ThemeID.peachSage.headline(30, relativeTo: .title))
                .foregroundStyle(brand.bg)
                .opacity(nameShown ? 1 : 0)
                .offset(y: logo / 2 + Space.s12 + (nameShown ? 0 : Space.s8))
        }
        .opacity(fading ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quiet Reading")
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(150))
            finish(duration: 0.2)
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { ribbonDown = true }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeOut(duration: 0.35)) { nameShown = true }
        try? await Task.sleep(for: .milliseconds(450))
        finish()
    }

    private func finish(duration: Double = 0.35) {
        guard !fading else { return }
        withAnimation(.easeInOut(duration: duration)) { fading = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { onFinished() }
    }
}

/// The bookmark ribbon of the "q": from tucked in (ends at the bowl) to full length with its notch.
nonisolated private struct Ribbon: Shape {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 38.4                     // logo artwork is 38.4 × 38.4
        let left = 20.25 * s, right = 24.3 * s, top = 9.735 * s
        let shortEnd = 20.1075 * s, fullEnd = 29.8575 * s
        let bottom = shortEnd + (fullEnd - shortEnd) * progress
        let notch = 2.25 * s * min(1, max(0, progress))
        var p = Path()
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: right, y: top))
        p.addLine(to: CGPoint(x: right, y: bottom))
        p.addLine(to: CGPoint(x: (left + right) / 2, y: bottom - notch))
        p.addLine(to: CGPoint(x: left, y: bottom))
        p.closeSubpath()
        return p
    }
}

#Preview { SplashView(onFinished: {}) }
