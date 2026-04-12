import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var store: ProcessStore!

  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private var signalSource: DispatchSourceSignal?
  private var idleIcon: NSImage?
  private var runningIcon: NSImage?

  func applicationDidFinishLaunching(_ notification: Notification) {
    store = ProcessStore()
    store.onIconChange = { [weak self] in self?.updateMenuBarIcon() }

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    updateMenuBarIcon()

    if let button = statusItem.button {
      button.action = #selector(togglePopover)
      button.target = self
    }

    popover = NSPopover()
    popover.contentSize = NSSize(width: 360, height: 500)
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(
      rootView: ContentView(store: store)
        .onAppear { AppNotifications.requestPermission() }
    )

    signal(SIGTERM, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated {
        self?.performCleanup()
      }
      exit(0)
    }
    source.resume()
    signalSource = source
  }

  nonisolated func applicationWillTerminate(_ notification: Notification) {
    MainActor.assumeIsolated {
      performCleanup()
    }
  }

  @objc private func togglePopover() {
    if popover.isShown {
      popover.close()
    } else if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate()
    }
  }

  private func updateMenuBarIcon() {
    let anyRunning = store.processes.contains { $0.isRunning }
    statusItem.button?.image = anyRunning ? cachedRunningIcon() : cachedIdleIcon()
  }

  private func cachedIdleIcon() -> NSImage? {
    if idleIcon == nil { idleIcon = makeIcon(running: false) }
    return idleIcon
  }

  private func cachedRunningIcon() -> NSImage? {
    if runningIcon == nil { runningIcon = makeIcon(running: true) }
    return runningIcon
  }

  private func makeIcon(running: Bool) -> NSImage? {
    guard
      let baseImage = NSImage(
        systemSymbolName: "terminal",
        accessibilityDescription: "devtail"
      )
    else { return nil }

    let dotSize: CGFloat = 4.5
    let dotGap: CGFloat = 1.5
    let totalWidth = running ? baseImage.size.width + dotGap + dotSize : baseImage.size.width
    let composited = NSImage(
      size: NSSize(width: totalWidth, height: baseImage.size.height),
      flipped: false
    ) { _ in
      baseImage.draw(in: NSRect(origin: .zero, size: baseImage.size))
      if running {
        let dotY = (baseImage.size.height - dotSize) / 2
        let dotRect = NSRect(x: baseImage.size.width + dotGap, y: dotY, width: dotSize, height: dotSize)
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
      }
      return true
    }
    composited.isTemplate = true
    return composited
  }

  private func performCleanup() {
    PopOutWindowManager.shared.closeAll()
    store?.stopAllForQuit()
  }
}
