import SwiftUI

/// 🧱 Components › Button (Figma 47:165). Full width.
/// - Primary: filled accent, one per screen.
/// - Secondary: accent border, no fill – the second most likely action.
/// - Outline: neutral border – low emphasis.
/// - Text: link style.
/// - Destructive: deletes or removes something.
/// Large = 48 pt, Small = 40 pt (hit area stays ≥ 44 pt).
struct QsButtonStyle: ButtonStyle {
    /// Figma property "Priority".
    enum Priority { case primary, secondary, outline, text, destructive }
    enum ButtonSize { case large, small }
    var priority: Priority = .primary
    var size: ButtonSize = .large

    func makeBody(configuration: Configuration) -> some View {
        QsButtonBody(configuration: configuration, priority: priority, size: size)
    }
}

private struct QsButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let priority: QsButtonStyle.Priority
    let size: QsButtonStyle.ButtonSize
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    private var colors: (fg: Color, bg: Color, border: Color) {
        let p = theme.palette
        let pressed = configuration.isPressed
        guard isEnabled else {
            switch priority {
            case .primary, .destructive: return (p.disabledInk, p.disabledBg, .clear)
            case .secondary: return (p.disabledInk, .clear, p.disabledInk)
            case .outline: return (p.disabledInk, p.disabledBg, p.disabledInk)
            case .text: return (p.disabledInk, .clear, .clear)
            }
        }
        switch priority {
        case .primary: return (p.onAccent, pressed ? p.accentPressed : p.accent, .clear)
        case .secondary: return (p.accentInk, pressed ? p.soft2 : .clear, pressed ? p.accentPressed : p.accent)
        case .outline: return (p.ink, pressed ? p.infoSoft : .clear, p.lineStrong)
        case .text: return (p.accentInk, pressed ? p.soft2 : .clear, .clear)
        case .destructive: return (p.onAccent, p.error, .clear)
        }
    }

    var body: some View {
        let c = colors
        let shape = RoundedRectangle(cornerRadius: theme.radii.btn, style: .continuous)
        configuration.label
            .font((size == .large ? Font.body : .subheadline).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(c.fg)
            .padding(.horizontal, size == .large ? Space.s24 : Space.s16)
            .frame(maxWidth: .infinity, minHeight: size == .large ? Size.button : Size.buttonSmall)
            .background(c.bg, in: shape)
            .overlay(shape.strokeBorder(c.border, lineWidth: Size.stroke))
            .contentShape(shape)
            .frame(minHeight: Size.touchIos)
    }
}
