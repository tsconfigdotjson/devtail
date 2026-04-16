import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
  var store: ProcessStore!

  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private var signalSource: DispatchSourceSignal?
  private var localMonitor: Any?
  private var globalMonitor: Any?
  private var idleIcon: NSImage?
  private var runningIcon: NSImage?

  func applicationDidFinishLaunching(_ notification: Notification) {
    store = ProcessStore()
    store.onIconChange = { [weak self] in self?.updateMenuBarIcon() }

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    updateMenuBarIcon()

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      guard let self else { return event }
      if event.window == self.statusItem.button?.window {
        self.togglePopover()
        return nil
      }
      if self.popover.isShown, event.window != self.popover.contentViewController?.view.window {
        self.popover.close()
      }
      return event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
      [weak self] _ in
      guard let self, self.popover.isShown else { return }
      self.popover.close()
    }

    popover = NSPopover()
    popover.contentSize = NSSize(width: 360, height: 500)
    popover.behavior = .applicationDefined
    popover.animates = false
    popover.delegate = self
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

  private func togglePopover() {
    if popover.isShown {
      popover.close()
    } else if let button = statusItem.button {
      NSApp.activate()
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  func popoverWillShow(_ notification: Notification) {
    statusItem.button?.highlight(true)
    if let window = popover.contentViewController?.view.window,
      let root = window.contentView
    {
      pinVisualEffectStateActive(in: root)
    }
  }

  func popoverDidShow(_ notification: Notification) {
    guard let window = popover.contentViewController?.view.window else { return }
    window.makeKey()
    if let root = window.contentView {
      pinVisualEffectStateActive(in: root)
    }
  }

  func popoverDidClose(_ notification: Notification) {
    statusItem.button?.highlight(false)
  }

  private func pinVisualEffectStateActive(in view: NSView) {
    if let effect = view as? NSVisualEffectView {
      effect.state = .active
    }
    for subview in view.subviews {
      pinVisualEffectStateActive(in: subview)
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
