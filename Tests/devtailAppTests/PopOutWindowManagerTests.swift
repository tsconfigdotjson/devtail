import AppKit
import DevtailKit
import Foundation
import Testing

@testable import devtail

@MainActor
@Suite(.serialized)
struct PopOutWindowManagerTests {

  init() { _ = NSApplication.shared }

  @Test func openWindowTracksWindowForBuffer() {
    let manager = PopOutWindowManager.shared
    manager.closeAll()

    let buffer = TerminalBuffer()
    manager.openWindow(buffer: buffer, title: "Test Window")

    // Opening again with the same buffer should reuse the existing window.
    manager.openWindow(buffer: buffer, title: "Test Window")

    manager.closeWindow(for: buffer)
    // Subsequent close is a no-op but should not crash.
    manager.closeWindow(for: buffer)
  }

  @Test func closeAllTearsDownAllWindows() {
    let manager = PopOutWindowManager.shared
    manager.closeAll()

    let a = TerminalBuffer()
    let b = TerminalBuffer()
    manager.openWindow(buffer: a, title: "A")
    manager.openWindow(buffer: b, title: "B")

    manager.closeAll()
    // After closeAll, closing specific buffers should be idempotent.
    manager.closeWindow(for: a)
    manager.closeWindow(for: b)
  }
}
