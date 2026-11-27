import SwiftUI

/// 🧱 Components › Progress bar. Track in chartTrack, fill in accent.
/// M = 8 pt (cards), S = 4 pt (grid tiles).
struct QsProgressBar: View {
    enum BarSize { case m, s }
    /// 0…1
    let value: Double
    var size: BarSize = .m
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.palette.chartTrack)
                Capsule().fill(theme.palette.accent)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: size == .m ? Space.s8 : Space.s4)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
