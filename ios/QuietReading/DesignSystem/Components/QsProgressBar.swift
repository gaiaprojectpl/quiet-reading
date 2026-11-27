import SwiftUI

/// 🧱 Components › Progress. 8 pt track in chartTrack, fill in accent.
struct QsProgressBar: View {
    /// 0…1
    let value: Double
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.palette.chartTrack)
                Capsule().fill(theme.palette.accent)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: Space.s8)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
