import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: ProcessStore?

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            store?.stopAllForQuit()
        }
    }
}
