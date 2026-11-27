import SwiftUI

/// 🧱 Components › Notification (Figma 47:1135): one colourful message, always at the top under
/// the status bar, 16 pt side margins. Hides after 4 s (6 s with an action), swipe up to dismiss,
/// announced by VoiceOver. For meaningful moments only (page saved, book added).
@Observable
final class NotificationCenterModel {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var message: String
        var actionTitle: String?
        var action: (() -> Void)?

        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    }

    private(set) var current: Item?
    private var hideTask: Task<Void, Never>?

    func show(_ title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let item = Item(title: title, message: message, actionTitle: actionTitle, action: action)
        current = item
        AccessibilityNotification.Announcement("\(title). \(message)").post()
        hideTask?.cancel()
        let seconds = actionTitle == nil ? Motion.toastShort : Motion.toastLong
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss(item.id)
        }
    }

    func dismiss(_ id: UUID? = nil) {
        guard id == nil || current?.id == id else { return }
        current = nil
    }
}

struct QsNotificationHost: ViewModifier {
    @Environment(NotificationCenterModel.self) private var center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let item = center.current {
                QsNotificationView(item: item, onClose: { center.dismiss(item.id) })
                    .padding(.horizontal, Space.s16)
                    .padding(.top, Space.s4)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .gesture(DragGesture(minimumDistance: 10).onEnded { if $0.translation.height < 0 { center.dismiss(item.id) } })
            }
        }
        .animation(.easeOut(duration: Motion.base), value: center.current)
    }
}

private struct QsNotificationView: View {
    let item: NotificationCenterModel.Item
    let onClose: () -> Void
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var badge = Space.s32 + Space.s4

    var body: some View {
        HStack(spacing: Space.s12) {
            Image("qs.check")
                .resizable()
                .frame(width: Size.iconM, height: Size.iconM)
                .foregroundStyle(theme.palette.onAccent)
                .frame(width: badge, height: badge)
                .background(theme.palette.success, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text(item.message).font(.subheadline)
            }
            .foregroundStyle(theme.palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle = item.actionTitle, let action = item.action {
                Button(actionTitle) { action(); onClose() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.palette.success)
                    .frame(minHeight: Size.touchIos)
            }
            Button(action: onClose) {
                Image("qs.close")
                    .resizable()
                    .frame(width: Size.iconS + 2, height: Size.iconS + 2)
                    .foregroundStyle(theme.palette.ink2)
                    .frame(width: Size.touchIos, height: Size.touchIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.vertical, Space.s12)
        .padding(.leading, Space.s16)
        .padding(.trailing, Space.s4)
        .background(theme.palette.successSoft, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .shadow(color: theme.palette.scrim.opacity(0.12), radius: 9, x: 0, y: 6)
        .accessibilityElement(children: .contain)
    }
}
