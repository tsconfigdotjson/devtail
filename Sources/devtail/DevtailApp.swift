import SwiftUI

@main
struct DevtailApp: App {
    @State private var store = ProcessStore()

    var body: some Scene {
        MenuBarExtra("Devtail", systemImage: "terminal") {
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
