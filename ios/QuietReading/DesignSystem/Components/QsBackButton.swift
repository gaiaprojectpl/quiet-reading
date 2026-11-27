import SwiftUI
import UIKit

/// 🧱 Components › Back button (iOS): chevron + "Back" in accentInk, 44 pt tall,
/// pressed = 40 % opacity. Read by VoiceOver as "Back, button".
struct QsBackButton: View {
    var action: (() -> Void)?
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var icon = Size.iconL

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            HStack(spacing: Space.s2) {
                Image("qs.backios")
                    .resizable()
                    .frame(width: icon, height: icon)
                    .accessibilityHidden(true)
                Text("Back")
                    .font(.body)
            }
            .foregroundStyle(theme.palette.accentInk)
            .padding(.leading, Space.s4)
            .padding(.trailing, Space.s8)
            .frame(minHeight: Size.touchIos)
            .contentShape(Rectangle())
        }
        .buttonStyle(FadeOnPress())
    }

    private struct FadeOnPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? 0.4 : 1)
        }
    }
}

/// Our screens hide the system navigation bar (it can't take the theme's back button and fonts),
/// which would also switch off the edge swipe to go back. This keeps the swipe working.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
