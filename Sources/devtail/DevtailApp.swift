import SwiftUI

@main
struct DevtailApp: App {
  @State private var store = ProcessStore()
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    MenuBarExtra {
      ContentView(store: store)
        .onAppear {
          appDelegate.store = store
          AppNotifications.requestPermission()
        }
    } label: {
      Image(systemName: "terminal")
        .overlay(alignment: .topTrailing) {
          if store.processes.contains(where: \.isRunning) {
            Circle()
              .frame(width: 5, height: 5)
              .offset(x: 2, y: -2)
          }
        }
    }
    .menuBarExtraStyle(.window)
  }
}
