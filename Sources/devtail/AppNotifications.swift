import Foundation
import UserNotifications

enum AppNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func processExited(name: String, exitCode: Int32) {
        let content = UNMutableNotificationContent()
        content.title = exitCode == 0 ? "Process Exited" : "Process Crashed"
        content.body = exitCode == 0
            ? "\(name) exited normally."
            : "\(name) exited with code \(exitCode)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
