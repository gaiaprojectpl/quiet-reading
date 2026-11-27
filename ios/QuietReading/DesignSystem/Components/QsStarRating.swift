import SwiftUI

/// 🧱 Components › Rating. Five 36 pt stars in accent; tap a star for a whole star, tap it again for a half.
/// VoiceOver: one adjustable control ("Rating, 4.5 stars", swipe up / down by half a star).
struct QsStarRating: View {
    @Binding var value: Double?
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bumped: Int?
    @ScaledMetric(relativeTo: .title) private var star = Space.s32 + Space.s4

    var body: some View {
        HStack(spacing: Space.s8) {
            ForEach(1...5, id: \.self) { index in
                Image(icon(for: index))
                    .resizable()
                    .frame(width: star, height: star)
                    .foregroundStyle(theme.palette.accent)
                    .scaleEffect(bumped == index && !reduceMotion ? 1.15 : 1)
                    .frame(minWidth: Size.touchIos, minHeight: Size.touchIos)
                    .contentShape(Rectangle())
                    .onTapGesture { tap(index) }
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(value.map { Text("\($0, format: .number) stars") } ?? Text("Not rated"))
        .accessibilityAdjustableAction { direction in
            let current = value ?? 0
            switch direction {
            case .increment: value = min(5, current + 0.5)
            case .decrement: value = current > 0.5 ? current - 0.5 : nil
            @unknown default: break
            }
        }
    }

    private func icon(for index: Int) -> String {
        let v = value ?? 0
        if v >= Double(index) { return "qs.star-fill" }
        if v >= Double(index) - 0.5 { return "qs.star-half" }
        return "qs.star-empty"
    }

    private func tap(_ index: Int) {
        let whole = Double(index)
        value = value == whole ? whole - 0.5 : whole
        // A small, soft bump on the tapped star.
        withAnimation(.easeOut(duration: Motion.fast)) { bumped = index }
        withAnimation(.easeOut(duration: Motion.base).delay(Motion.fast)) { bumped = nil }
    }
}
