import SwiftUI

/// 🧱 Components › Notification (Figma 47:1135): one colourful message, always at the top under
/// the status bar, 16 pt side margins. Hides after 4 s (6 s with an action), swipe up to dismiss,
/// announced by VoiceOver. For meaningful moments only (page saved, book added).
@Observable
final class NotificationCenterModel {
    enum Kind { case success, info, warning, error }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        var kind: Kind = .success
        var title: String
        var message: String
        var actionTitle: String?
        var action: (() -> Void)?

        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    }

    private(set) var current: Item?
    private var hideTask: Task<Void, Never>?

    func show(_ title: String, message: String, kind: Kind = .success, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let item = Item(kind: kind, title: title, message: message, actionTitle: actionTitle, action: action)
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
        .sensoryFeedback(trigger: center.current) { _, new in
            switch new?.kind { case nil: nil; case .error: .error; case .warning: .warning; default: .success }
        }
    }
}

private struct QsNotificationView: View {
    let item: NotificationCenterModel.Item
    let onClose: () -> Void
    @Environment(\.theme) private var theme

    private var badgeColor: Color {
        switch item.kind {
        case .success: theme.palette.success
        case .info: theme.palette.accent
        case .warning: theme.palette.warning
        case .error: theme.palette.error
        }
    }

    private var backgroundColor: Color {
        switch item.kind {
        case .success: theme.palette.successSoft
        case .info: theme.palette.soft2
        case .warning: theme.palette.warningSoft
        case .error: theme.palette.errorSoft
        }
    }
    private var icon: String {
        switch item.kind {
        case .success: "qs.check"
        case .info: "qs.info"
        case .warning: "qs.bell"
        case .error: "qs.alert"
        }
    }
    @ScaledMetric(relativeTo: .subheadline) private var badge = Space.s32 + Space.s4

    var body: some View {
        HStack(spacing: Space.s12) {
            Image(icon)
                .resizable()
                .frame(width: Size.iconM, height: Size.iconM)
                .foregroundStyle(theme.palette.onAccent)
                .frame(width: badge, height: badge)
                .background(badgeColor, in: Circle())
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
                    .foregroundStyle(item.kind == .success ? theme.palette.success : item.kind == .warning ? theme.palette.warning : item.kind == .error ? theme.palette.error : theme.palette.accentInk)
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
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        .shadow(color: theme.palette.scrim.opacity(0.12), radius: 9, x: 0, y: 6)
        .accessibilityElement(children: .contain)
    }
}
