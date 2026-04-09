import SwiftUI

@main
struct DevtailApp: App {
    @State private var store = ProcessStore()
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Devtail", systemImage: "terminal") {
            ContentView(store: store)
                .onAppear {
                    appDelegate.store = store
                    AppNotifications.requestPermission()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
