import AppKit

enum AppNotifications {
    static func requestPermission() {
        // NSUserNotification doesn't require explicit permission.
        // When the app is bundled as a .app with a bundle ID,
        // switch to UNUserNotificationCenter for modern notifications.
    }

    @MainActor
    static func processExited(name: String, exitCode: Int32) {
        let title = exitCode == 0 ? "Process Exited" : "Process Crashed"
        let body = exitCode == 0
            ? "\(name) exited normally."
            : "\(name) exited with code \(exitCode)."

        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
