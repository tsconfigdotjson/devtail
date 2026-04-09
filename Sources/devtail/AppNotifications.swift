import AppKit
import UserNotifications

enum AppNotifications {
    private static var isBundledApp: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    static func requestPermission() {
        guard isBundledApp else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @MainActor
    static func processExited(name: String, exitCode: Int32) {
        let title = exitCode == 0 ? "Process Exited" : "Process Crashed"
        let body = exitCode == 0
            ? "\(name) exited normally."
            : "\(name) exited with code \(exitCode)."

        if isBundledApp {
            sendUNNotification(title: title, body: body)
        } else {
            sendScriptNotification(title: title, body: body)
        }
    }

    // MARK: - Bundled .app — UNUserNotificationCenter

    private static func sendUNNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Unbundled executable — osascript fallback

    private static func sendScriptNotification(title: String, body: String) {
        let escaped = { (s: String) -> String in
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(escaped(body))\" with title \"\(escaped(title))\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }
}
