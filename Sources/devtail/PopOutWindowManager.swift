import AppKit
import SwiftUI
import DevtailKit

@MainActor
final class PopOutWindowManager {
    static let shared = PopOutWindowManager()

    /// Keyed by buffer's ObjectIdentifier so each buffer gets one window.
    private var windows: [ObjectIdentifier: NSWindow] = [:]
    private var delegates: [ObjectIdentifier: WindowCloseDelegate] = [:]

    func openWindow(buffer: TerminalBuffer, title: String) {
        let key = ObjectIdentifier(buffer)

        // If window already exists, bring it to front
        if let existing = windows[key], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(rootView: PopOutProcessView(buffer: buffer, title: title))
        window.contentView = hostingView
        window.title = title
        window.minSize = NSSize(width: 300, height: 200)
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = WindowCloseDelegate { [weak self] in
            self?.windows.removeValue(forKey: key)
            self?.delegates.removeValue(forKey: key)
            self?.hideAppIfNoWindows()
        }
        window.delegate = delegate
        delegates[key] = delegate
        windows[key] = window

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow(for buffer: TerminalBuffer) {
        let key = ObjectIdentifier(buffer)
        if let window = windows.removeValue(forKey: key) {
            window.close()
        }
        delegates.removeValue(forKey: key)
        hideAppIfNoWindows()
    }

    func closeAll() {
        for (_, window) in windows {
            window.close()
        }
        windows.removeAll()
        delegates.removeAll()
        hideAppIfNoWindows()
    }

    private func hideAppIfNoWindows() {
        if windows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Window Close Delegate

private final class WindowCloseDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    let onClose: @MainActor () -> Void

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            onClose()
        }
    }
}
