import SwiftUI

/// 🧱 Components › Segmented control: soft2 track, the selected segment on surface.
/// Used for Progress / Quotes / Notes and Page / Percent.
struct QsSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.s4) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(theme.palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: Size.touchIos - Space.s8)
                        .background(selected ? theme.palette.surface : .clear,
                                    in: RoundedRectangle(cornerRadius: theme.radii.inner, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(Space.s4)
        .background(theme.palette.soft2, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
        .gentleAnimation(selection, duration: Motion.fast)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
