import SwiftUI

/// Gentle motion, shared by every screen. Durations come from the Motion tokens.
/// With Reduce Motion on, movement becomes a plain change or a fade – never a slide, scale or bounce.

extension View {
    /// Eases changes of `value` (selection, progress, appearing content). Off with Reduce Motion.
    func gentleAnimation<V: Equatable>(_ value: V, duration: Double = Motion.base) -> some View {
        modifier(GentleAnimation(value: value, duration: duration))
    }

    /// Content that softly rises into place when it first appears (Finished moment, empty states).
    func gentleAppear(delay: Double = 0) -> some View {
        modifier(GentleAppear(delay: delay))
    }
}

private struct GentleAnimation<V: Equatable>: ViewModifier {
    let value: V
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: duration), value: value)
    }
}

private struct GentleAppear: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : Space.s12)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? Motion.fast : Motion.slow).delay(reduceMotion ? 0 : delay)) {
                    shown = true
                }
            }
    }
}

/// Press feedback for tappable cards and tiles: a slight settle (or just a dim with Reduce Motion).
struct QsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressable(isPressed: configuration.isPressed) { configuration.label }
    }

    private struct Pressable<Label: View>: View {
        let isPressed: Bool
        @ViewBuilder var label: Label
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            label
                .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: Motion.fast), value: isPressed)
        }
    }
}
