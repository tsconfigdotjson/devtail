import SwiftUI

@main
struct DevtailApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    Settings { EmptyView() }
  }
}
