import SwiftUI

/// Buttons from 🧱 Components › Button (Primary, Secondary, Outline, Text). Full width, 48 pt.
struct QsButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, outline, text }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        QsButtonBody(configuration: configuration, kind: kind)
    }
}

private struct QsButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: QsButtonStyle.Kind
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    private var colors: (fg: Color, bg: Color, border: Color) {
        let p = theme.palette
        guard isEnabled else { return (p.disabledInk, p.disabledBg, .clear) }
        let pressed = configuration.isPressed
        switch kind {
        case .primary: return (p.onAccent, pressed ? p.accentPressed : p.accent, .clear)
        case .secondary: return (p.accentInk, pressed ? p.soft : p.soft2, .clear)
        case .outline: return (p.accentInk, pressed ? p.soft2 : .clear, p.lineStrong)
        case .text: return (p.accentInk, pressed ? p.soft2 : .clear, .clear)
        }
    }

    var body: some View {
        let c = colors
        let shape = RoundedRectangle(cornerRadius: theme.radii.btn, style: .continuous)
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(c.fg)
            .padding(.horizontal, Space.s16)
            .frame(maxWidth: .infinity, minHeight: Size.button)
            .background(c.bg, in: shape)
            .overlay(shape.strokeBorder(c.border, lineWidth: Size.stroke))
            .contentShape(shape)
    }
}
