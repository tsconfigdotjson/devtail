import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var store: ProcessStore?

  private var signalSource: DispatchSourceSignal?

  func applicationDidFinishLaunching(_ notification: Notification) {
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

  private func performCleanup() {
    PopOutWindowManager.shared.closeAll()
    store?.stopAllForQuit()
  }
}
