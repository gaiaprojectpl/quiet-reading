import UserNotifications
import Foundation

/// Opens the right place when a notification is tapped (reminder → page update, recap → year in books).
/// The delegate is called off the main thread, so it only forwards the link to the app.
nonisolated final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationTaps()
    static let reminderCategory = "reminder"
    static let opened = Notification.Name("qsOpenLink")

    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let update = UNNotificationAction(identifier: "update", title: String(localized: "Update"), options: [.foreground])
        let finished = UNNotificationAction(identifier: "finished", title: String(localized: "Finished"), options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.reminderCategory, actions: [update, finished], intentIdentifiers: [])])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        var link = response.notification.request.content.userInfo["link"] as? String
        if response.actionIdentifier == "finished" { link = "quietreading://finish-current" }
        if response.actionIdentifier == "update" { link = "quietreading://update-current" }
        guard let link, let url = URL(string: link) else { return }
        await MainActor.run { NotificationCenter.default.post(name: Self.opened, object: url) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
