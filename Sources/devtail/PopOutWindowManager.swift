import AppKit
import DevtailKit
import SwiftUI

@MainActor
final class PopOutWindowManager {
  static let shared = PopOutWindowManager()

  private var windows: [ObjectIdentifier: NSWindow] = [:]
  private var delegates: [ObjectIdentifier: WindowCloseDelegate] = [:]

  func openWindow(buffer: TerminalBuffer, title: String) {
    let key = ObjectIdentifier(buffer)

    if let existing = windows[key], existing.isVisible {
      existing.makeKeyAndOrderFront(nil)
      NSApp.activate()
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
      styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    window.titlebarAppearsTransparent = true
    window.isOpaque = false
    window.backgroundColor = .clear

    let hostingView = NSHostingView(rootView: PopOutProcessView(buffer: buffer))
    window.contentView = hostingView
    window.title = title
    window.minSize = NSSize(width: 300, height: 200)
    window.isReleasedWhenClosed = false
    window.center()
    window.setFrameAutosaveName("devtail.popout")

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
    NSApp.activate()
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

@MainActor
private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
  let onClose: () -> Void

  init(onClose: @escaping () -> Void) {
    self.onClose = onClose
  }

  nonisolated func windowWillClose(_ notification: Notification) {
    MainActor.assumeIsolated {
      onClose()
    }
  }
}
