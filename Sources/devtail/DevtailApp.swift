import SwiftUI

@main
struct DevtailApp: App {
    @State private var isRunning = true

    var body: some Scene {
        MenuBarExtra("Devtail", systemImage: "terminal") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Devtail")
                    .font(.headline)
                Divider()
                Button("About Devtail") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(4)
        }
    }
}
